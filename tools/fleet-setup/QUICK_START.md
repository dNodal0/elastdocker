# 🚀 Quick Start - Elastic Agent Configuration

## Configuration en 20 Minutes

### Étape 1: Créer Ingest Pipelines (2 min)

```bash
cd elastic-agent-setup

export ELASTIC_PASSWORD="ton_password"
./scripts/create-ingest-pipelines.sh
```

**Résultat:**
- ✅ `logs-fail2ban-security`
- ✅ `logs-asterisk-security`  
- ✅ `logs-auth-security`

---

### Étape 2: Configurer Fleet dans Kibana (5 min)

#### 2.1 Créer Agent Policy

```
Kibana → Fleet → Agent policies → Create agent policy

Nom: Security-Monitoring-NUCs
Description: Monitoring fail2ban, Asterisk, SSH
```

#### 2.2 Ajouter Integration: Fail2ban

```
Add integration → Custom Logs

Integration name: Fail2ban-Logs
Log file path: /var/log/fail2ban.log
Dataset name: fail2ban
Namespace: security

Advanced options:
  Custom configurations:
    pipeline: logs-fail2ban-security
  
  Processors:
    - add_fields:
        target: ''
        fields:
          log_type: fail2ban
```

#### 2.3 Ajouter Integration: Asterisk

```
Add integration → Custom Logs

Integration name: Asterisk-Security-Logs

Log file paths:
  - /var/log/asterisk/security
  - /var/log/asterisk/messages
  - /var/log/asterisk/full

Dataset name: asterisk
Namespace: security

Exclude lines:
  - ^\[.*\] DEBUG
  - ^\[.*\] VERBOSE

Multiline:
  type: pattern
  pattern: ^\[
  negate: true
  match: after

Advanced options:
  Custom configurations:
    pipeline: logs-asterisk-security
  
  Processors:
    - add_fields:
        target: ''
        fields:
          log_type: asterisk
```

#### 2.4 Ajouter Integration: System (Auth)

```
Add integration → System

Nom: System-Auth-Logs

Enable:
  ✅ System logs

Advanced options (dans "System logs"):
  Custom configurations:
    pipeline: logs-auth-security
  
  Processors:
    - add_fields:
        target: ''
        fields:
          log_type: auth
    - drop_event:
        when:
          contains:
            message: "CRON"
```

---

### Étape 3: Installer Elastic Agent sur NUCs (5 min par NUC)

#### 3.1 Obtenir commande d'installation

```
Fleet → Agents → Add agent
→ Select existing policy: Security-Monitoring-NUCs
→ Copier la commande
```

#### 3.2 Sur NUC1

```bash
# SSH vers NUC1
ssh user@nuc1

# Coller la commande Fleet (exemple)
curl -L -O https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-8.10.2-linux-x86_64.tar.gz
tar xzvf elastic-agent-8.10.2-linux-x86_64.tar.gz
cd elastic-agent-8.10.2-linux-x86_64

sudo ./elastic-agent install \
  --url=https://your-fleet-server:8220 \
  --enrollment-token=YOUR_ENROLLMENT_TOKEN

# Vérifier
sudo elastic-agent status
```

#### 3.3 Sur NUC2

Répéter l'étape 3.2

#### 3.4 Vérifier dans Fleet

```
Fleet → Agents

Devrait voir:
  ✅ NUC1 - Healthy
  ✅ NUC2 - Healthy
```

---

### Étape 4: Vérifier Data Streams (2 min)

```
Kibana → Dev Tools

# Voir les data streams créés
GET _data_stream/logs-*-security*

# Compter les documents
GET logs-*-security*/_count

# Voir des exemples
GET logs-fail2ban-security/_search?size=5
GET logs-asterisk-security/_search?size=5
GET logs-system.auth-*/_search?size=5&q=event.type:*
```

---

### Étape 5: Créer Index Pattern (1 min)

```
Stack Management → Index Patterns → Create index pattern

Index pattern: logs-*-security*
Time field: @timestamp

→ Create
```

---

### Étape 6: Tester Queries (2 min)

```
Kibana → Discover
→ Select index pattern: logs-*-security*

Queries de test:
  # Tous les événements sécurité
  event.type:*
  
  # Bans fail2ban
  data_stream.dataset:fail2ban AND action:ban
  
  # Attaques Asterisk
  data_stream.dataset:asterisk AND event.type:asterisk_attack_attempt
  
  # Échecs SSH
  event.type:ssh_failed_auth
  
  # GeoIP check
  geoip.country_name:*
```

---

### Étape 7: Créer Dashboards (3 min)

```bash
# Script à venir ou créer manuellement dans Kibana

Kibana → Dashboards → Create dashboard

Visualisations recommandées:
1. Timeline attaques (line chart)
2. Top IPs (table)
3. Map géographique (maps)
4. Event types (pie chart)
5. Par NUC (bar chart)
```

---

## 🔍 Troubleshooting Rapide

### Logs ne remontent pas

```bash
# Sur NUC
sudo elastic-agent status
sudo tail -f /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson

# Vérifier permissions logs
ls -la /var/log/fail2ban.log
ls -la /var/log/asterisk/
ls -la /var/log/auth.log

# Si permissions insuffisantes
sudo chmod +r /var/log/fail2ban.log
sudo usermod -a -G asterisk elastic-agent
```

### Pipeline ne parse pas

```bash
# Tester pipeline dans Dev Tools
POST _ingest/pipeline/logs-fail2ban-security/_simulate
{
  "docs": [
    {
      "_source": {
        "message": "2025-01-31 10:15:23,456 fail2ban.actions [12345]: NOTICE [sshd] Ban 185.220.101.45"
      }
    }
  ]
}

# Vérifier résultat
# Should have: attacker_ip, event.type, geoip.country_name
```

### GeoIP ne fonctionne pas

```bash
# Vérifier GeoIP database dans ES
GET _ingest/geoip/stats

# Si manquante, télécharger manuellement
curl -L -O https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-City.mmdb
curl -L -O https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-ASN.mmdb

# Placer dans /usr/share/elasticsearch/config/ingest-geoip/
```

---

## ✅ Checklist

- [ ] Ingest pipelines créés (3x)
- [ ] Fleet policy "Security-Monitoring-NUCs" créée
- [ ] Integration Fail2ban ajoutée + pipeline associé
- [ ] Integration Asterisk ajoutée + pipeline associé
- [ ] Integration System ajoutée + pipeline associé
- [ ] Elastic Agent installé NUC1
- [ ] Elastic Agent installé NUC2
- [ ] Agents "Healthy" dans Fleet
- [ ] Data streams visibles (logs-*-security*)
- [ ] Index pattern créé
- [ ] Queries de test fonctionnent
- [ ] GeoIP affiche pays
- [ ] Dashboards créés

---

## 🎯 Queries Essentielles

```lucene
# Dashboard Vue Globale
event.type:(banned OR asterisk_attack_attempt OR ssh_failed_auth)

# Par type de log
data_stream.dataset:fail2ban
data_stream.dataset:asterisk
data_stream.dataset:system.auth

# Par NUC
host.name:"nuc1"
host.name:"nuc2"

# Top attaquants
attacker_ip:* | top attacker_ip

# Par pays
attacker_ip:* | top geoip.country_name

# Récidivistes (>3 attaques)
attacker_ip:* | stats count by attacker_ip | where count > 3
```

---

## 📊 Exemple Visualizations

### Timeline Attaques
```
Type: Line
Metrics: Count
Buckets: 
  - X-Axis: Date Histogram (@timestamp, Auto interval)
  - Split Series: Terms (event.type, Top 5)
```

### Top IPs
```
Type: Data Table
Metrics: Count
Buckets:
  - Split Rows: Terms (attacker_ip, Top 20)
  - Split Rows: Terms (geoip.country_name, Top 1)
  - Split Rows: Terms (event.type, Top 5)
```

### Map Géographique
```
Type: Maps
Layer: Documents
  Index pattern: logs-*-security*
  Geospatial field: geoip.location
```

---

## 🚀 Performance Tips

### Optimiser Agent

```yaml
# Dans Fleet → Settings → Agent policy
# Advanced settings

monitoring.enabled: true
monitoring.logs: true
monitoring.metrics: true

# Dans chaque integration, ajuster:
processors:
  - drop_event:
      when:
        regexp:
          message: "^\\s*$"  # Drop empty lines
```

### Optimiser Ingest

```json
// Augmenter bulk size
PUT _cluster/settings
{
  "transient": {
    "bulk.queue_size": 200
  }
}
```

---

## 📚 Ressources

- [Elastic Agent Docs](https://www.elastic.co/guide/en/fleet/current/index.html)
- [Fleet Management](https://www.elastic.co/guide/en/fleet/current/fleet-overview.html)
- [Ingest Pipelines](https://www.elastic.co/guide/en/elasticsearch/reference/current/ingest.html)
- [Custom Logs Integration](https://www.elastic.co/guide/en/integrations/current/log.html)

---

**⏱️ Temps total: ~20 minutes**

**Prochaine étape:** Créer dashboards et alertes !
