# 🔒 Configuration des Logs de Sécurité depuis Clients Distants

## 📋 Vue d'ensemble

Ce guide explique comment configurer un client Ubuntu distant pour envoyer ses logs de sécurité (authentification SSH, syslog, fail2ban, détection d'intrusion) vers votre instance ElasticDocker Kibana.

### ✨ Architecture

```
┌─────────────────────────────┐
│  Client Ubuntu Distant      │
│  (192.168.2.101 ou autre)   │
│                             │
│  ┌─────────────────────┐   │
│  │ Filebeat 9.2.3      │   │──┐
│  │ /var/log/auth.log   │   │  │
│  │ /var/log/syslog     │   │  │
│  │ /var/log/fail2ban   │   │  │
│  └─────────────────────┘   │  │
└─────────────────────────────┘  │
                                 │ Port 5044
                                 │ (Beats Protocol)
                                 ▼
┌─────────────────────────────────────────────────────────────┐
│  Serveur ElasticDocker (192.168.2.102)                      │
│                                                              │
│  ┌──────────────┐    ┌───────────────┐    ┌──────────────┐ │
│  │  Logstash    │───▶│ Elasticsearch │───▶│   Kibana     │ │
│  │  Port 5044   │    │  Port 9200    │    │  Port 5601   │ │
│  │  Pipeline    │    │  Index:       │    │  Dashboard   │ │
│  │  security-   │    │  security-    │    │  Visualize   │ │
│  │  logs.conf   │    │  logs-*       │    │              │ │
│  └──────────────┘    └───────────────┘    └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 🎯 Objectifs

- ✅ Centraliser les logs de sécurité de tous vos serveurs Ubuntu
- ✅ Détecter les tentatives d'intrusion SSH (échecs, utilisateurs invalides)
- ✅ Monitorer les actions fail2ban (bannissements IP)
- ✅ Analyser les événements système critiques
- ✅ Géolocaliser les IP sources des attaques
- ✅ Visualiser dans Kibana avec dashboards

---

## 🖥️ Configuration Serveur (192.168.2.102)

### ✅ Étape 1 : Vérifier la configuration Logstash (Déjà fait)

Les fichiers suivants sont déjà configurés dans votre ElasticDocker :

#### **1. Pipeline security-logs.conf**
- **Emplacement** : `logstash/pipeline/security-logs.conf`
- **Fonction** : Parse les logs auth.log, syslog, fail2ban
- **Fonctionnalités** :
  - Détection SSH : failed password, successful auth, invalid user
  - Enrichissement GeoIP pour localiser les attaquants
  - Classification par sévérité : high, medium, info
  - Index Elasticsearch : `security-logs-YYYY.MM.dd`

#### **2. Configuration pipelines.yml**
- **Emplacement** : `logstash/config/pipelines.yml`
- **Ligne ajoutée** :
```yaml
- pipeline.id: security-logs
  path.config: "/usr/share/logstash/pipeline/security-logs.conf"
  queue.type: persisted
  pipeline.batch.size: 200
  pipeline.workers: 2
```

#### **3. Beats Input configuré**
- **Port** : 5044
- **Host** : 0.0.0.0 (écoute toutes interfaces)
- **Protocole** : Beats (Filebeat, Metricbeat, etc.)

### ✅ Étape 2 : Configurer le firewall (Si nécessaire)

Votre firewall est actuellement **inactif** (`ufw status: inactive`). Si vous l'activez ou utilisez `iptables`, ouvrez le port 5044 :

#### **Avec UFW :**
```bash
# Autoriser Beats depuis votre réseau local
sudo ufw allow from 192.168.2.0/24 to any port 5044 proto tcp comment 'Logstash Beats Input'

# Ou depuis une IP spécifique
sudo ufw allow from 192.168.2.101 to any port 5044 proto tcp

# Vérifier
sudo ufw status numbered
```

#### **Avec iptables :**
```bash
# Autoriser depuis le réseau local
sudo iptables -A INPUT -p tcp -s 192.168.2.0/24 --dport 5044 -j ACCEPT -m comment --comment "Logstash Beats"

# Sauvegarder les règles
sudo netfilter-persistent save
```

#### **Vérifier le port ouvert :**
```bash
# Vérifier que Logstash écoute sur 5044
sudo ss -tulpn | grep 5044

# Devrait afficher :
# tcp   LISTEN 0   128   0.0.0.0:5044   0.0.0.0:*   users:(("java",pid=XXXX))
```

### ✅ Étape 3 : Redémarrer Logstash avec le nouveau pipeline

```bash
# Depuis le répertoire elastdocker/
cd /home/admsrv/elastdocker

# Redémarrer Logstash uniquement
docker compose restart logstash

# Vérifier les logs
docker logs elastic-logstash-1 --tail 50

# Attendre le message :
# "Successfully started Logstash API endpoint {:port=>9600, :ssl_enabled=>false}"
# "Pipeline started {\"pipeline.id\"=>\"security-logs\"}"
```

### ✅ Étape 4 : Vérifier que le pipeline est chargé

```bash
# API Logstash pour voir les pipelines actifs
curl -s http://localhost:9600/_node/stats/pipelines?pretty | grep -A 5 "security-logs"

# Devrait afficher :
# "security-logs" : {
#   "events" : {
#     "in" : 0,
#     "filtered" : 0,
#     "out" : 0
```

---

## 💻 Configuration Client Ubuntu Distant

### Étape 1 : Installation de Filebeat 9.2.3

**Sur le client Ubuntu distant** (exemple : 192.168.2.101), exécutez :

```bash
# 1. Ajouter la clé GPG Elastic
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg

# 2. Ajouter le repository Elastic 9.x
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/9.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-9.x.list

# 3. Installer Filebeat
sudo apt-get update
sudo apt-get install filebeat=9.2.3

# 4. Vérifier la version
filebeat version
# Devrait afficher : filebeat version 9.2.3
```

### Étape 2 : Copier la configuration Filebeat

Le fichier `filebeat-client-config.yml` est prêt dans votre repository ElasticDocker.

**Sur le serveur (192.168.2.102)** :
```bash
# Afficher la configuration
cat /home/admsrv/elastdocker/filebeat-client-config.yml
```

**Sur le client (192.168.2.101)** :

**Option A : Copie via SCP** (depuis le serveur vers le client) :
```bash
# Depuis le serveur
scp /home/admsrv/elastdocker/filebeat-client-config.yml user@192.168.2.101:/tmp/

# Sur le client
sudo cp /tmp/filebeat-client-config.yml /etc/filebeat/filebeat.yml
```

**Option B : Copie manuelle** :
```bash
# Sur le client
sudo nano /etc/filebeat/filebeat.yml
# Coller le contenu du fichier filebeat-client-config.yml
```

**Option C : Téléchargement direct si disponible** :
```bash
# Si vous avez mis le fichier sur un serveur web
curl -o /tmp/filebeat.yml https://votre-serveur/filebeat-client-config.yml
sudo cp /tmp/filebeat.yml /etc/filebeat/filebeat.yml
```

### Étape 3 : Vérifier les permissions des fichiers logs

Filebeat doit pouvoir lire les fichiers de logs :

```bash
# Vérifier les permissions
ls -l /var/log/auth.log /var/log/syslog /var/log/kern.log

# Si Filebeat ne peut pas lire, ajouter l'utilisateur filebeat au groupe adm
sudo usermod -a -G adm filebeat

# Ou ajuster les permissions (moins recommandé)
sudo chmod 644 /var/log/auth.log /var/log/syslog
```

### Étape 4 : Tester la configuration Filebeat

```bash
# Tester la configuration (ne démarre pas Filebeat)
sudo filebeat test config -c /etc/filebeat/filebeat.yml

# Devrait afficher :
# Config OK

# Tester la connexion vers Logstash
sudo filebeat test output -c /etc/filebeat/filebeat.yml

# Devrait afficher :
# logstash: 192.168.2.102:5044...
#   connection...
#     parse host... OK
#     dns lookup... OK
#     addresses: 192.168.2.102
#     dial up... OK
#   TLS... WARN secure connection disabled
#   talk to server... OK
```

### Étape 5 : Démarrer Filebeat

```bash
# Activer au démarrage
sudo systemctl enable filebeat

# Démarrer le service
sudo systemctl start filebeat

# Vérifier le statut
sudo systemctl status filebeat

# Devrait afficher :
# ● filebeat.service - Filebeat sends log files to Logstash or directly to Elasticsearch.
#    Loaded: loaded (/lib/systemd/system/filebeat.service; enabled; vendor preset: enabled)
#    Active: active (running) since ...
```

### Étape 6 : Vérifier les logs Filebeat

```bash
# Voir les logs du service
sudo journalctl -u filebeat -f --since "5 minutes ago"

# Ou voir le fichier de log
sudo tail -f /var/log/filebeat/filebeat

# Messages attendus :
# "Connection to backoff(async(tcp://192.168.2.102:5044)) established"
# "Non-zero metrics in the last 30s" (indique que des événements sont envoyés)
```

---

## 🧪 Tests et Validation

### Test 1 : Générer des événements de test sur le client

```bash
# Test SSH failed authentication (depuis un autre terminal)
ssh utilisateur_inexistant@localhost

# Test sudo (génère un événement auth.log)
sudo ls /root

# Vérifier que les logs sont générés
sudo tail /var/log/auth.log
```

### Test 2 : Vérifier réception dans Logstash (serveur)

```bash
# Voir les logs Logstash en temps réel
docker logs elastic-logstash-1 -f

# Chercher des messages comme :
# "Beats input: client connected" {"ip"=>"192.168.2.101"}
```

### Test 3 : Vérifier l'index Elasticsearch (serveur)

```bash
# Lister les indices security-logs
curl -k -u elastic:t9U6nXEme6nJ0IbM1bG2D2uq2ToWnx5Hh3EQSaZxUrU= \
  https://localhost:9200/_cat/indices/security-logs-*?v

# Devrait afficher un index comme :
# health status index                   docs.count
# yellow open   security-logs-2026.01.29  15

# Requêter les derniers événements
curl -k -u elastic:t9U6nXEme6nJ0IbM1bG2D2uq2ToWnx5Hh3EQSaZxUrU= \
  "https://localhost:9200/security-logs-*/_search?pretty&size=5&sort=@timestamp:desc"
```

### Test 4 : Visualiser dans Kibana

1. **Ouvrir Kibana** :
   - URL : https://kibana.elastic.local (avec Traefik)
   - Ou : https://192.168.2.102:5601 (direct)
   - Login : `elastic` / `t9U6nXEme6nJ0IbM1bG2D2uq2ToWnx5Hh3EQSaZxUrU=`

2. **Créer un Data View** :
   - Menu → Stack Management → Data Views
   - Cliquer "Create data view"
   - Name : `Security Logs`
   - Index pattern : `security-logs-*`
   - Timestamp field : `@timestamp`
   - Cliquer "Save data view to Kibana"

3. **Explorer les données** :
   - Menu → Discover
   - Sélectionner "Security Logs" data view
   - Voir les logs SSH, syslog, etc.

4. **Filtres utiles** :
   ```
   tags: "ssh_failed_auth"          # Tentatives SSH échouées
   tags: "threat"                    # Tous événements menaçants
   ssh_source_ip: "1.2.3.4"         # Depuis une IP spécifique
   security_severity: "high"         # Sévérité haute uniquement
   ```

---

## 📊 Dashboards Kibana Recommandés

### Dashboard 1 : Security Overview

**Visualisations à créer** :

1. **Metric : Total Failed SSH Attempts (Last 24h)**
   - Query : `tags: "ssh_failed_auth"`
   - Aggregation : Count

2. **Line Chart : SSH Events Over Time**
   - X-axis : @timestamp (histogram)
   - Y-axis : Count
   - Split by : tags (ssh_failed_auth vs ssh_successful_auth)

3. **Pie Chart : Top 10 Attacker IPs**
   - Query : `tags: "threat"`
   - Aggregation : Terms on `ssh_source_ip.keyword`

4. **Map : Geographic Location of Attacks**
   - Layer : Documents
   - Geospatial field : `geoip.location`
   - Query : `tags: "threat"`

5. **Data Table : Recent Failed Attempts**
   - Columns : @timestamp, ssh_user, ssh_source_ip, geoip.country_name
   - Query : `tags: "ssh_failed_auth"`
   - Sort : @timestamp desc
   - Size : 10

### Dashboard 2 : Fail2ban Actions

1. **Metric : Total Bans (Last 24h)**
   - Query : `tags: "fail2ban_action"`

2. **Data Table : Banned IPs**
   - Columns : fail2ban_timestamp, banned_ip, fail2ban_action, geoip.country_name

---

## 🔒 Sécurisation (Production)

### 1. Activer SSL/TLS pour Beats → Logstash

**Sur le serveur**, modifier `logstash/pipeline/security-logs.conf` :

```ruby
input {
    beats {
        port => 5044
        host => "0.0.0.0"

        # Activer SSL/TLS
        ssl => true
        ssl_certificate => "/certs/logstash/logstash.crt"
        ssl_key => "/certs/logstash/logstash.key"
        ssl_certificate_authorities => ["/certs/ca/ca.crt"]
        ssl_verify_mode => "force_peer"  # Valide le certificat client
    }
}
```

**Sur le client**, modifier `/etc/filebeat/filebeat.yml` :

```yaml
output.logstash:
  hosts: ["192.168.2.102:5044"]

  # Activer SSL/TLS
  ssl.enabled: true
  ssl.certificate_authorities: ["/etc/filebeat/certs/ca.crt"]
  ssl.certificate: "/etc/filebeat/certs/client.crt"
  ssl.key: "/etc/filebeat/certs/client.key"
```

### 2. Restreindre l'accès réseau

```bash
# Firewall : autoriser UNIQUEMENT les IPs de vos clients
sudo ufw delete allow 5044
sudo ufw allow from 192.168.2.101 to any port 5044 proto tcp
sudo ufw allow from 192.168.2.105 to any port 5044 proto tcp
# ... répéter pour chaque client
```

### 3. Rotation des logs Filebeat

Sur le client, configurer logrotate pour `/var/log/filebeat/filebeat` :

```bash
sudo nano /etc/logrotate.d/filebeat
```

Contenu :
```
/var/log/filebeat/filebeat {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
```

---

## 🐛 Dépannage

### Problème 1 : Filebeat ne peut pas se connecter à Logstash

**Symptômes** :
```
Failed to connect to backoff(async(tcp://192.168.2.102:5044)): dial tcp: connect: connection refused
```

**Solutions** :
```bash
# 1. Vérifier que Logstash écoute sur le serveur
sudo ss -tulpn | grep 5044

# 2. Tester la connectivité réseau depuis le client
telnet 192.168.2.102 5044
# Ou
nc -zv 192.168.2.102 5044

# 3. Vérifier le firewall sur le serveur
sudo ufw status
sudo iptables -L -n | grep 5044

# 4. Vérifier les logs Logstash
docker logs elastic-logstash-1 | grep -i "beats"
```

### Problème 2 : Filebeat démarre mais n'envoie rien

**Symptômes** :
```
Non-zero metrics in the last 30s: 0 events sent
```

**Solutions** :
```bash
# 1. Vérifier que les fichiers sont lisibles
sudo -u filebeat cat /var/log/auth.log

# 2. Vérifier la configuration Filebeat
sudo filebeat test config -c /etc/filebeat/filebeat.yml

# 3. Activer le mode debug
sudo filebeat -e -d "*" -c /etc/filebeat/filebeat.yml

# 4. Vérifier le registry Filebeat (état de lecture des fichiers)
sudo cat /var/lib/filebeat/registry/filebeat/log.json | jq

# 5. Forcer la lecture depuis le début (ATTENTION : envoie tous les logs historiques)
sudo systemctl stop filebeat
sudo rm -rf /var/lib/filebeat/registry
sudo systemctl start filebeat
```

### Problème 3 : Logs arrivent mais ne sont pas parsés

**Symptômes** : Champs `ssh_user`, `ssh_source_ip` absents dans Elasticsearch

**Solutions** :
```bash
# 1. Vérifier le pipeline Logstash
docker logs elastic-logstash-1 | grep -i "grok"

# 2. Tester le grok pattern manuellement
# Aller sur : https://grokdebug.herokuapp.com/
# Pattern : %{SYSLOGTIMESTAMP:syslog_timestamp} %{SYSLOGHOST:syslog_hostname} %{DATA:syslog_program}(?:\[%{POSINT:syslog_pid}\])?: %{GREEDYDATA:syslog_message}
# Sample : Jan 29 14:23:45 ubuntu-client sshd[1234]: Failed password for invalid user test from 1.2.3.4 port 12345 ssh2

# 3. Vérifier les tags sur les événements
# Dans Kibana Discover, filtrer par : tags: "*"
```

### Problème 4 : Index non créé dans Elasticsearch

**Symptômes** : `curl` ne trouve pas `security-logs-*`

**Solutions** :
```bash
# 1. Vérifier que Logstash envoie vers Elasticsearch
docker logs elastic-logstash-1 | grep -i "elasticsearch"

# 2. Vérifier manuellement les indices
curl -k -u elastic:PASSWORD https://localhost:9200/_cat/indices?v

# 3. Vérifier la configuration output dans security-logs.conf
docker exec elastic-logstash-1 cat /usr/share/logstash/pipeline/security-logs.conf | grep -A 10 "output"

# 4. Tester la connexion Logstash → Elasticsearch
docker exec elastic-logstash-1 curl -k -u elastic:PASSWORD https://elasticsearch:9200/_cluster/health
```

### Problème 5 : GeoIP ne fonctionne pas

**Symptômes** : Champ `geoip` absent ou vide

**Solutions** :
```bash
# 1. Vérifier que le module GeoIP est présent dans Logstash
docker exec elastic-logstash-1 ls -la /usr/share/logstash/vendor/bundle/jruby/*/gems/ | grep geoip

# 2. Télécharger la base GeoIP manuellement si nécessaire
# (Normalement incluse dans l'image Logstash 9.2.3)

# 3. Vérifier les logs d'erreur GeoIP
docker logs elastic-logstash-1 | grep -i geoip
```

---

## 📝 Checklist de déploiement

### Serveur (192.168.2.102)

- [x] Pipeline `security-logs.conf` créé
- [x] Pipeline ajouté à `pipelines.yml`
- [ ] Logstash redémarré avec `docker compose restart logstash`
- [ ] Pipeline `security-logs` actif (vérifier avec API)
- [ ] Port 5044 ouvert dans le firewall (si activé)
- [ ] Port 5044 accessible depuis le réseau (test `nc -zv`)

### Client Ubuntu (192.168.2.101 ou autre)

- [ ] Filebeat 9.2.3 installé (`filebeat version`)
- [ ] Configuration `filebeat.yml` copiée et adaptée
- [ ] IP serveur correcte : `192.168.2.102:5044`
- [ ] Permissions lectures logs OK (`sudo -u filebeat cat /var/log/auth.log`)
- [ ] Test configuration : `filebeat test config` → OK
- [ ] Test connexion : `filebeat test output` → OK
- [ ] Filebeat démarré : `systemctl status filebeat` → active (running)
- [ ] Logs Filebeat : connexion établie

### Validation End-to-End

- [ ] Index `security-logs-*` créé dans Elasticsearch
- [ ] Événements visibles avec `curl` ou Kibana Discover
- [ ] Champs parsés : `ssh_user`, `ssh_source_ip`, `geoip`, `security_severity`
- [ ] Data View créé dans Kibana
- [ ] Dashboard ou visualisation fonctionnel

---

## 🔧 Maintenance

### Monitoring régulier

```bash
# Sur le serveur : vérifier le débit d'événements
curl -s http://localhost:9600/_node/stats/pipelines | jq '.pipelines."security-logs".events'

# Vérifier la taille des indices
curl -k -u elastic:PASSWORD https://localhost:9200/_cat/indices/security-logs-*?v&h=index,docs.count,store.size

# Sur le client : vérifier l'envoi Filebeat
sudo filebeat export ilm-policy
sudo journalctl -u filebeat | tail -20
```

### ILM (Index Lifecycle Management)

Configurer la rétention automatique pour éviter de saturer le disque :

```bash
# Créer une politique ILM : garder 30 jours, puis supprimer
curl -k -u elastic:PASSWORD -X PUT "https://localhost:9200/_ilm/policy/security-logs-policy" \
-H 'Content-Type: application/json' -d'
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {
            "max_size": "50GB",
            "max_age": "1d"
          }
        }
      },
      "delete": {
        "min_age": "30d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
'

# Appliquer la politique à l'index pattern
# (Déjà configuré dans security-logs.conf avec ilm_enabled => auto)
```

---

## 📚 Ressources

- **Elastic Beats** : https://www.elastic.co/guide/en/beats/filebeat/9.2/index.html
- **Logstash Grok Patterns** : https://github.com/logstash-plugins/logstash-patterns-core/tree/main/patterns
- **GeoIP Filter** : https://www.elastic.co/guide/en/logstash/9.2/plugins-filters-geoip.html
- **Kibana Visualizations** : https://www.elastic.co/guide/en/kibana/9.2/dashboard.html

---

**Généré le** : 2026-01-29
**Version** : Elasticsearch 9.2.3

🤖 **Generated with [Claude Code](https://claude.com/claude-code)**

Co-Authored-By: Claude <noreply@anthropic.com>
