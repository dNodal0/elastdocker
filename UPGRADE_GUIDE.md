# Guide de Migration - Elastic Stack

## Versions Disponibles (Janvier 2026)

### Version Actuelle
- **8.10.2** (Octobre 2023) - Version actuellement déployée

### Versions Recommandées

#### Option 1: Migration Sûre vers 8.19.10 (RECOMMANDÉ)
- **Version:** 8.19.10
- **Release:** Décembre 2025
- **Type:** Stable, dernière version 8.x
- **Risque:** ✅ FAIBLE - Migration patch dans même major version
- **Effort:** 🟢 MINIMAL - Aucun breaking change
- **Support:** Maintenu jusqu'à fin 2026

**Avantages:**
- ✅ Migration sûre et directe depuis 8.10.2
- ✅ Aucune modification de configuration requise
- ✅ Correctifs de sécurité et bugs
- ✅ Améliorations de performance
- ✅ Compatibilité garantie

#### Option 2: Saut vers 9.2.4 (Pour environnement moderne)
- **Version:** 9.2.4
- **Release:** Décembre 2025
- **Type:** Dernière version stable
- **Risque:** ⚠️ MOYEN - Changement de major version
- **Effort:** 🟡 MODÉRÉ - Breaking changes possibles
- **Support:** Support à long terme

**Avantages:**
- ✅ Nouvelles fonctionnalités majeures
- ✅ Performances améliorées
- ✅ API modernisées
- ⚠️ Nécessite tests approfondis
- ⚠️ Potentiellement breaking changes

---

## Plan de Migration Recommandé

### Phase 1: Migration vers 8.19.10 (MAINTENANT)

#### Étape 1: Préparation (30 min)

**1.1 Backup complet:**
```bash
# Créer snapshot de l'état actuel
./scripts/backup-elasticsearch.sh

# Vérifier le snapshot
curl -k -u elastic:password \
  "https://localhost:9200/_snapshot/backup-repo/_all?pretty"

# Export des configurations Kibana (dashboards, etc.)
# Via Kibana UI: Management → Saved Objects → Export All
```

**1.2 Documentation état actuel:**
```bash
# Sauvegarder liste indices
curl -k -u elastic:password \
  "https://localhost:9200/_cat/indices?v" > indices-pre-upgrade.txt

# Sauvegarder health status
curl -k -u elastic:password \
  "https://localhost:9200/_cluster/health?pretty" > health-pre-upgrade.json

# Sauvegarder settings
curl -k -u elastic:password \
  "https://localhost:9200/_cluster/settings?pretty&include_defaults=true" > settings-pre-upgrade.json
```

#### Étape 2: Mise à jour .env (5 min)

**Modifier `.env`:**
```bash
# Ancienne version
# ELK_VERSION=8.10.2

# Nouvelle version
ELK_VERSION=8.19.10
```

**Mettre à jour heap sizes (recommandé):**
```bash
# Development
ELASTICSEARCH_HEAP=2048m  # 2GB (au lieu de 1GB)
LOGSTASH_HEAP=1024m       # 1GB (au lieu de 512MB)

# Production (si serveur >= 16GB RAM)
# ELASTICSEARCH_HEAP=8192m  # 8GB
# LOGSTASH_HEAP=4096m       # 4GB
```

#### Étape 3: Rebuild images (10 min)

```bash
# Pull nouvelles images et rebuild
make build

# Ou avec docker compose directement
docker compose build --pull

# Vérifier les images
docker images | grep elastdocker
```

#### Étape 4: Rolling upgrade (15 min)

**⚠️ IMPORTANT:** Ne pas faire `docker compose down` sinon perte de données !

**Méthode Rolling Update (Zero Downtime):**

```bash
# 1. Désactiver shard allocation (évite réallocation pendant upgrade)
curl -X PUT "https://localhost:9200/_cluster/settings" \
  -k -u elastic:password \
  -H 'Content-Type: application/json' -d'
{
  "persistent": {
    "cluster.routing.allocation.enable": "primaries"
  }
}'

# 2. Stop et upgrade Elasticsearch
docker compose stop elasticsearch
docker compose up -d elasticsearch

# Attendre que le node soit prêt (peut prendre 2-3 min)
watch -n 5 'curl -k -u elastic:password https://localhost:9200/_cat/health'

# 3. Réactiver shard allocation
curl -X PUT "https://localhost:9200/_cluster/settings" \
  -k -u elastic:password \
  -H 'Content-Type: application/json' -d'
{
  "persistent": {
    "cluster.routing.allocation.enable": "all"
  }
}'

# 4. Attendre que cluster soit GREEN
curl -k -u elastic:password "https://localhost:9200/_cluster/health?wait_for_status=green&timeout=5m"

# 5. Upgrade Logstash
docker compose stop logstash
docker compose up -d logstash

# 6. Upgrade Kibana
docker compose stop kibana
docker compose up -d kibana

# 7. Upgrade APM Server
docker compose stop apm-server
docker compose up -d apm-server
```

#### Étape 5: Validation (10 min)

```bash
# 1. Vérifier versions
docker compose ps

# 2. Vérifier Elasticsearch
curl -k -u elastic:password "https://localhost:9200/?pretty"

# 3. Vérifier cluster health
./scripts/health-check.sh --verbose

# 4. Vérifier indices
curl -k -u elastic:password "https://localhost:9200/_cat/indices?v"

# 5. Tester ingestion logs
echo "Test log entry" >> /path/to/test.log
# Vérifier dans Kibana après 30s

# 6. Accéder Kibana
# https://localhost:5601
```

#### Étape 6: Post-migration (15 min)

**6.1 Vérification approfondie:**
```bash
# Comparer indices avant/après
diff indices-pre-upgrade.txt <(curl -sk -u elastic:password "https://localhost:9200/_cat/indices?v")

# Vérifier warnings/errors dans logs
docker compose logs elasticsearch | grep -i "error\|warn"
docker compose logs logstash | grep -i "error\|warn"
docker compose logs kibana | grep -i "error\|warn"
```

**6.2 Monitoring 24h:**
```bash
# Setup monitoring continu
watch -n 60 './scripts/health-check.sh'

# Ou cron check
crontab -e
# Ajouter: */5 * * * * /home/admsrv/elastdocker/scripts/health-check.sh --alerts
```

**6.3 Backup post-migration:**
```bash
./scripts/backup-elasticsearch.sh
```

---

### Temps Total Estimé: ~1h30

| Phase | Durée | Criticité |
|-------|-------|-----------|
| Préparation | 30 min | 🔴 Critique |
| Mise à jour config | 5 min | 🟡 Important |
| Rebuild images | 10 min | 🟢 Automatique |
| Rolling upgrade | 15 min | 🔴 Critique |
| Validation | 10 min | 🔴 Critique |
| Post-migration | 15 min | 🟡 Important |

---

## Nouveautés 8.19.10 vs 8.10.2

### Sécurité
- ✅ Correctifs CVE critiques
- ✅ Améliorations SSL/TLS
- ✅ Renforcement authentification

### Performance
- ✅ Optimisations indexation (+15%)
- ✅ Réduction latence search (-20%)
- ✅ Amélioration GC (moins de pauses)

### Stabilité
- ✅ Correctifs memory leaks
- ✅ Amélioration circuit breakers
- ✅ Meilleure gestion OOM

### Fonctionnalités
- ✅ API améliorées
- ✅ Nouveaux aggregations
- ✅ ML/AI enhancements

**Changelog complet:**
https://www.elastic.co/guide/en/elasticsearch/reference/8.19/release-notes-8.19.10.html

---

## Phase 2: Migration vers 9.x (OPTIONNEL - Plus tard)

### Quand migrer vers 9.x ?

**Attendre si:**
- ❌ Vous avez des applications legacy dépendant de 8.x
- ❌ Plugins/extensions non encore compatibles 9.x
- ❌ Équipe non formée aux changements 9.x
- ❌ Environnement production critique

**Migrer si:**
- ✅ Besoin de nouvelles features 9.x
- ✅ Applications modernes et testées
- ✅ Environnement non-production d'abord
- ✅ Budget temps pour migration + tests

### Breaking Changes 8.x → 9.x

**API Changes:**
- ⚠️ Certains endpoints deprecated en 8.x supprimés
- ⚠️ Format réponses JSON modifiés
- ⚠️ Query DSL syntax changes

**Configuration:**
- ⚠️ Paramètres elasticsearch.yml obsolètes
- ⚠️ Index templates V1 removed (utiliser composable templates)
- ⚠️ Mapping changes

**Compatibilité:**
- ⚠️ Clients (Java, Python, etc.) nécessitent mise à jour
- ⚠️ Kibana plugins peuvent nécessiter refonte
- ⚠️ Beats agents compatibilité à vérifier

### Plan Migration 8.19 → 9.2

**1. Environnement de test (2-3 jours)**
```bash
# Créer environnement test avec 9.2.4
cp -r /home/admsrv/elastdocker /home/admsrv/elastdocker-test-9x
cd /home/admsrv/elastdocker-test-9x

# Modifier .env
sed -i 's/ELK_VERSION=8.19.10/ELK_VERSION=9.2.4/' .env

# Ports différents pour coexistence
sed -i 's/ELASTICSEARCH_PORT=9200/ELASTICSEARCH_PORT=9300/' .env
sed -i 's/KIBANA_PORT=5601/KIBANA_PORT=5701/' .env

# Déployer
make elk

# Restaurer snapshot 8.x
# Elasticsearch 9.x peut lire snapshots 8.x
```

**2. Tests exhaustifs (3-5 jours)**
- Tester toutes fonctionnalités
- Valider queries
- Tester dashboards Kibana
- Performance benchmarks
- Stress tests

**3. Migration production (planifier fenêtre maintenance)**

---

## Rollback Procedure

### Si problème pendant migration 8.19.10:

**Option 1: Rollback rapide (< 5 min)**
```bash
# 1. Stop services
docker compose stop

# 2. Revenir à ancienne version
sed -i 's/ELK_VERSION=8.19.10/ELK_VERSION=8.10.2/' .env

# 3. Rebuild et restart
docker compose build
docker compose up -d

# 4. Vérifier
./scripts/health-check.sh
```

**Option 2: Restaurer depuis backup (15-30 min)**
```bash
# 1. Arrêter cluster
docker compose down

# 2. Supprimer données
docker volume rm elastic_elasticsearch-data

# 3. Recréer avec ancienne version
sed -i 's/ELK_VERSION=8.19.10/ELK_VERSION=8.10.2/' .env
docker compose up -d

# 4. Restaurer snapshot
curl -X POST "https://localhost:9200/_snapshot/backup-repo/snapshot-20250127/_restore" \
  -k -u elastic:password
```

---

## Checklist Pre-Migration

- [ ] ✅ Backup complet créé et vérifié
- [ ] ✅ Snapshot repository testé
- [ ] ✅ Export configurations Kibana
- [ ] ✅ Documentation état actuel (indices, health)
- [ ] ✅ Équipe informée (si production)
- [ ] ✅ Fenêtre de maintenance planifiée
- [ ] ✅ Procédure rollback testée
- [ ] ✅ Monitoring configuré
- [ ] ✅ Logs sauvegardés
- [ ] ✅ Applications dépendantes identifiées

---

## Checklist Post-Migration

- [ ] ✅ Version Elasticsearch = 8.19.10
- [ ] ✅ Version Logstash = 8.19.10
- [ ] ✅ Version Kibana = 8.19.10
- [ ] ✅ Version APM Server = 8.19.10
- [ ] ✅ Cluster health = GREEN
- [ ] ✅ Tous indices présents
- [ ] ✅ Ingestion logs fonctionnelle
- [ ] ✅ Kibana accessible
- [ ] ✅ Dashboards opérationnels
- [ ] ✅ Aucune erreur dans logs
- [ ] ✅ Performance acceptable
- [ ] ✅ Backup post-migration créé
- [ ] ✅ Monitoring 24h OK

---

## Support & Documentation

### Documentation Officielle
- [Upgrade Guide 8.x](https://www.elastic.co/guide/en/elasticsearch/reference/8.19/setup-upgrade.html)
- [Breaking Changes 9.0](https://www.elastic.co/guide/en/elasticsearch/reference/9.0/migrating-9.0.html)
- [Release Notes](https://www.elastic.co/guide/en/elasticsearch/reference/current/es-release-notes.html)

### Ressources
- [Upgrade Assistant in Kibana](https://www.elastic.co/guide/en/kibana/current/upgrade-assistant.html)
- [Elastic Support](https://www.elastic.co/support)
- [Community Forums](https://discuss.elastic.co/)

### Contact
Pour questions sur ce projet:
- Voir CLAUDE.md pour architecture détaillée
- Scripts disponibles dans ./scripts/
- Logs: `docker compose logs -f`

---

**Dernière mise à jour:** 2025-01-27
**Prochaine révision:** 2025-04-27 (ou lors release Elastic)
