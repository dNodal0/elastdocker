# ElasticDocker – Stack ELK 9.2.3 Fleet-Managed

**Dernière mise à jour :** 2026-05-21
**Version ELK :** 9.2.3
**Mode de gestion :** Elastic Fleet (agents managés)

---

## Architecture

### Serveurs

| Hôte | Rôle | OS | Particularités |
|------|------|----|----------------|
| **ny** | Docker host principal | Ubuntu | Héberge toute la stack ELK en Docker |
| **nuc** | Agent distant | Linux (fish shell) | Asterisk PBX, logs SIP/sécurité |
| **ibmac** | Agent distant | macOS | Poste de travail |
| **Bibo** | Agent distant | Linux | Actuellement offline |

### Containers Docker (ny)

| Container | Image | Ports | Rôle |
|-----------|-------|-------|------|
| elasticsearch | elasticsearch:9.2.3 | 9200, 9300 | Cluster single-node |
| kibana | kibana:9.2.3 | 5601 | Interface web |
| logstash | logstash:9.2.3 | 5044, 9600 | Pipeline de traitement |
| apm-server | apm-server:9.2.3 | 8200 | APM |
| fleet-server | elastic-agent:9.2.3 | 8220, 9001/udp | Fleet Server + agent local + pfSense syslog |
| traefik | traefik:latest | 80, 443 | Reverse proxy TLS |
| grafana | grafana:latest | 3000 | Dashboards et visualisation |
| elasticsearch-exporter | prometheus-elasticsearch-exporter | 9114 | Métriques Prometheus (legacy) |
| logstash-exporter | logstash-exporter | 9304 | Métriques Prometheus (legacy) |
| **jesse** | salehmir/jesse:latest | **9000, 8888, 9001** | **Trading bot Jesse Pro — sur réseau elastic + jesse_network** |

### Jesse Trading Bot (`/home/admsrv/ib_jesse/`)

| Fichier | Description |
|---------|-------------|
| `docker-compose.yml` | Jesse + PostgreSQL + Redis (réseaux : jesse_network + elastic) |
| `.env` | Config DB, license token, password dashboard |
| `jesse-config/config.py` | Config exchange Binance/Sandbox, DB host=postgres |
| `jesse-config/routes.py` | Routes actives (stratégie + exchange + timeframe) |
| `strategies/` | Stratégies : AlligatorV2, BinanceSpotAdvanced, BitcoinEthereumV3/V4, EMBIA_V3, SuperScalper, SlowTrendFollowing... |

**Accès :** http://192.168.2.102:9000 — password : voir `.env` → `JESSE_PASSWORD`

**Pièges Jesse connus :**
- `DATABASE_URL` doit pointer sur `postgres` (nom container), jamais `db` ou `localhost`
- `jesse-config/config.py` : `host: 'postgres'` (pas `db`)
- La commande docker doit être `jesse run` (pas `jesse install-live && jesse run` — le token LICENSE_API_TOKEN est expiré/invalide → crash en boucle)
- Logs Jesse dans `/home/admsrv/ib_jesse/logs/` (vide tant qu'aucune session de trading active)

### Fichiers Docker Compose

| Fichier | Contenu |
|---------|---------|
| `docker-compose.yml` | ES, Kibana, Logstash, APM Server + volumes snapshots |
| `docker-compose.fleet.yml` | Fleet Server avec Docker socket monté |
| `docker-compose.monitor.yml` | Exporteurs Prometheus (legacy, à supprimer) |
| `docker-compose.traefik.yml` | Reverse proxy Traefik |
| `docker-compose.grafana.yml` | Grafana dashboards |
| `docker-compose.setup.yml` | Setup initial (certs, passwords) |
| `docker-compose.nodes.yml` | Config multi-nœuds (non utilisé) |

### Réseau Docker

- Réseau interne : les containers communiquent par nom de service
- **Important** : les intégrations Fleet doivent utiliser les noms Docker (`elasticsearch:9200`, `kibana:5601`, `logstash:9600`) et **jamais** `localhost` depuis fleet-server

---

## Fleet & Agents

### Agents enregistrés

| Agent | Policy | Status |
|-------|--------|--------|
| fleet-server (ny) | fleet-server-policy | Online |
| nuc | Agent policy 2 (e7398cde) | Online |
| ibmac | Default policy | Online |
| Bibo | Agent policy 2 (e7398cde) | Offline |

### Intégrations Fleet (fleet-server-policy)

| Intégration | Type | Détails |
|-------------|------|---------|
| ELK-Elasticsearch-Logs-Metrics | elasticsearch | Logs serveur + stack monitoring (→ elasticsearch:9200) |
| ELK-Kibana-Logs-Metrics | kibana | Logs + stack monitoring (→ kibana:5601) |
| ELK-Logstash-Logs-Metrics | logstash | Logs + stack monitoring (→ logstash:9600) |
| ELK-Docker-Metrics | docker | 7 streams métriques (socket /var/run/docker.sock) |
| pfSense-Firewall-Logs | pfsense | Logs firewall via syslog UDP 9001 |
| System integration | system | Métriques et logs système |

### Intégrations Fleet (Agent policy 2 – nuc/Bibo)

| Intégration | Type | Détails |
|-------------|------|---------|
| Asterisk-SIP-Security-Logs | filestream | Logs `/var/log/asterisk/security` et `/var/log/asterisk/messages` |
| System integration | system | Métriques et logs système |

### Configuration Asterisk importante

- Dataset custom : `asterisk_security`
- Pipeline ingest : `logs-asterisk-security` (grok + kv + geoip)
- Multiline : pattern `^\[`, negate true, match after
- Exclude : `DEBUG`, `VERBOSE`, fichiers `.gz` et rotatés `\.[0-9]+$`
- Data stream : `logs-asterisk_security-security`

### Configuration pfSense

**Intégration Fleet :** `pfSense-Firewall-Logs` (package pfsense 1.25.0)

| Paramètre | Valeur |
|-----------|--------|
| Input type | UDP syslog |
| Listen port | 9001 |
| Listen address | 0.0.0.0 |
| Timezone | Europe/Paris |
| Data stream | logs-pfsense.log-default |

**Configuration pfSense requise :**

Dans pfSense → Status > System Logs > Settings :
- Remote Logging Options : ✅ Enable
- Remote log servers : `192.168.2.102:9001`
- Remote Syslog Contents : Everything (ou Filter Logs uniquement)

**Dashboards Kibana inclus :**
- `[Logs pfSense] Overview`
- `[Logs pfSense] Firewall`

**Note :** Le pipeline Logstash pfsense est désactivé (voir `logstash/config/pipelines.yml`). L'intégration Fleet est privilégiée.

---

## Sécurité (SIEM)

### Règles de détection

- **1511 règles préinstallées**, 54 activées
- Filtrage : `OS: Linux`, `OS: macOS`, `Domain: Endpoint`, `Domain: Network`
- Exclusions : Windows, Cloud, AWS, Azure, GCP, vendor-specific

### Blocages iptables (nuc)

| IP | Raison | Date |
|----|--------|------|
| 64.31.3.53 | Brute force SIP (18 282 tentatives) | 2026-02-02 |
| 194.26.192.102 | Scan SIP (88 tentatives) | 2026-02-02 |

Règles persistées : `/etc/iptables.rules` sur nuc

---

## Cycle de vie des données (ILM)

### Policies ILM

| Policy | Hot (rollover) | Delete | Appliquée à |
|--------|---------------|--------|-------------|
| security-logs-lifecycle | 90 jours | 365 jours | system.auth, system.syslog, macos_auth |
| system-logs-lifecycle | 30 jours | 90 jours | (disponible) |
| stack-monitoring-lifecycle | 14 jours | 30 jours | ES/Kibana/Logstash stack_monitoring.* |
| metrics-lifecycle | 30 jours | 60 jours | docker.*, system.* métriques |

### Application via @custom component templates

Les policies ILM sont appliquées via des component templates `*@custom` (seul moyen compatible avec Fleet data streams).

---

## Snapshots

- **Repository** : `local-backups` (type fs, `/usr/share/elasticsearch/snapshots`)
- **Volume Docker** : `elasticsearch-snapshots` monté dans ES
- **SLM Policy** : `daily-snapshots`
  - Cron : tous les jours à 2h00 (`0 0 2 * * ?`)
  - Rétention : 30 jours, min 5, max 30 snapshots
- **Config ES** : `path.repo: ["/usr/share/elasticsearch/snapshots"]`

---

## Accès

| Service | URL | Credentials |
|---------|-----|-------------|
| Kibana | https://kibana.elastic.local | elastic / voir `.env` |
| Elasticsearch | https://elasticsearch:9200 (interne) | elastic / voir `.env` |
| Fleet | https://fleet.elastic.local:8220 | elastic / voir `.env` |
| Grafana | http://localhost:3000 | admin / admin |
| Traefik Dashboard | http://localhost:8080 | - |

---

## Grafana

### Datasources pré-configurés

| Datasource | Index Pattern | Usage |
|------------|---------------|-------|
| Elasticsearch | * | Principal (défaut) |
| Elasticsearch-Logs | logs-* | Logs système, apps |
| Elasticsearch-Metrics | metrics-* | Métriques système |
| Elasticsearch-pfSense | logs-pfsense* | Logs firewall |

### Dashboards

| Dashboard | Contenu |
|-----------|---------|
| Infrastructure Overview | CPU, RAM, Disk, Events par host |

### Provisioning

Les datasources et dashboards sont auto-provisionnés via :
- `grafana/provisioning/datasources/elasticsearch.yml`
- `grafana/provisioning/dashboards/json/*.json`

---

## Fichiers clés

| Fichier | Description |
|---------|-------------|
| `.env` | Variables d'environnement (gitignored, contient credentials) |
| `elasticsearch/config/elasticsearch.yml` | Config ES + path.repo snapshots |
| `Makefile` | Orchestration des compose files |
| `docs/` | Documentation historique (13 fichiers .md) |

---

## Notes opérationnelles

### Commandes courantes

```bash
# Démarrer la stack
cd ~/elastdocker && make elk

# Status des containers
docker ps --format "table {{.Names}}\t{{.Status}}"

# Vérifier Fleet agents
curl -sk -u elastic:$PASS https://kibana.elastic.local/api/fleet/agents?perPage=10 | jq '.items[] | {name: .local_metadata.host.hostname, status}'

# Lister les intégrations d'une policy
curl -sk -u elastic:$PASS https://kibana.elastic.local/api/fleet/package_policies?perPage=100 | jq '.items[] | select(.policy_id=="fleet-server-policy") | .name'

# Snapshot manuel
curl -sk -u elastic:$PASS -XPUT "https://localhost:9200/_slm/policy/daily-snapshots/_execute"
```

### API Fleet – Modifier une intégration

```bash
# 1. GET la policy complète
curl -sk -u "$AUTH" "https://kibana.elastic.local/api/fleet/package_policies/$ID" | jq '.item' > policy.json

# 2. Modifier le JSON (supprimer: id, version, revision, created_at, created_by, updated_at, updated_by, spaceIds)

# 3. PUT le JSON modifié
curl -sk -u "$AUTH" -H "kbn-xsrf: true" -H "Content-Type: application/json" \
  -XPUT "https://kibana.elastic.local/api/fleet/package_policies/$ID" -d @policy.json
```

### Pièges connus

- **fish shell sur nuc** : utiliser `sudo bash -c '...'` pour la syntaxe bash
- **Fleet hosts** : toujours utiliser les noms Docker, jamais localhost
- **ILM + Fleet data streams** : utiliser `@custom` component templates, pas des index templates classiques
- **Circuit breaker ES** : peut bloquer les requêtes à ~1.3GB RAM, attendre et réessayer
- **Asterisk logs rotatés** : exclure `\.[0-9]+$` sinon l'agent tente de lire des fichiers énormes
- **Docker socket** : doit être monté dans fleet-server pour l'intégration Docker metrics
- **Snapshot permissions** : le volume doit appartenir à uid 1000 (user ES dans le container)
- **ES cluster RED après restart** : throttling à 4 primaries simultanées → lancer les commandes ci-dessous
- **Jesse install-live** : le token LICENSE_API_TOKEN est invalide → utiliser `jesse run` directement

### Commande de récupération ES cluster RED

Après un restart d'Elasticsearch, si le cluster est RED avec des centaines de shards unassigned (raison CLUSTER_RECOVERED) :

```bash
source ~/elastdocker/.env

# 1. Augmenter le parallélisme de récupération
curl -sk -u "elastic:${ELASTIC_PASSWORD}" -X PUT "https://localhost:9200/_cluster/settings" \
  -H "Content-Type: application/json" -d '{
    "transient": {
      "cluster.routing.allocation.enable": "all",
      "cluster.routing.allocation.node_initial_primaries_recoveries": 20,
      "cluster.routing.allocation.node_concurrent_recoveries": 10,
      "indices.recovery.max_bytes_per_sec": "100mb"
    }
  }'

# 2. Déclencher le rerouting
curl -sk -u "elastic:${ELASTIC_PASSWORD}" -X POST "https://localhost:9200/_cluster/reroute?retry_failed=true"

# 3. Surveiller (attendre status yellow ou green)
watch -n10 'source ~/elastdocker/.env && curl -sk -u "elastic:${ELASTIC_PASSWORD}" "https://localhost:9200/_cluster/health" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[\"status\"], d[\"active_shards\"], \"active,\", d[\"unassigned_shards\"], \"unassigned\")"'
```

---

## Historique des changements majeurs

| Date | Changement |
|------|-----------|
| 2026-02-08 | Grafana ajouté avec datasources ES et dashboard Infrastructure |
| 2026-02-08 | Intégration pfSense Fleet ajoutée (UDP 9001), pipeline Logstash désactivé |
| 2026-02-08 | README.md mis à jour avec architecture Fleet-managed |
| 2026-02-08 | Makefile : ajout commandes `make fleet` et `make traefik` |
| 2026-02-02 | Suppression legacy Filebeat/Metricbeat, migration complète vers Fleet |
| 2026-02-02 | ILM policies créées (4 policies, @custom templates) |
| 2026-02-02 | Snapshots configurés (SLM daily, 30j rétention) |
| 2026-02-02 | SIEM : 54 règles de détection activées (Linux/macOS/Network/Endpoint) |
| 2026-02-02 | Docker metrics intégration ajoutée sur fleet-server |
| 2026-02-02 | Asterisk SIP logs corrigés et opérationnels (17 044 docs) |
| 2026-02-02 | Blocage IPs attaquantes SIP (64.31.3.53, 194.26.192.102) |
| 2026-02-02 | Documentation réorganisée dans docs/ |
| 2026-05-21 | Jesse trading bot intégré : réseau elastic, logs montés dans fleet-server |
| 2026-05-21 | Jesse docker-compose corrigé : DATABASE_URL, config.py host, suppression install-live |
| 2026-05-21 | Procédure de récupération ES cluster RED documentée (throttling primaries) |
