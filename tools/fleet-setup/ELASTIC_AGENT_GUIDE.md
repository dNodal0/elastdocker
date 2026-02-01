# 🚀 Configuration Elastic Agent - Security Monitoring

## Architecture avec Elastic Agent

```
NUC1/NUC2 (Elastic Agent)
    ├── Fail2ban logs
    ├── Asterisk logs  
    └── Auth logs
         │
         ↓ (Fleet managed)
         │
    Elasticsearch
         ↓
    Kibana Dashboards
```

---

## 📋 Étape 1: Configurer Fleet (Kibana)

### 1.1 Activer Fleet

```
Kibana → Menu ≡ → Management → Fleet
→ Fleet Settings
→ Add Fleet Server (si pas déjà fait)
```

**Fleet Server Host:**
```
https://your-kibana:8220
```

### 1.2 Créer Agent Policy

```
Fleet → Agent policies → Create agent policy
```

**Nom:** `Security Monitoring - NUCs`
**Description:** `Monitoring fail2ban, Asterisk, SSH logs`

---

## 📋 Étape 2: Ajouter Integrations

### 2.1 Custom Logs Integration (pour Fail2ban)

```
Fleet → Agent policies → Security Monitoring - NUCs
→ Add integration → Custom Logs
```

**Configuration:**

| Champ | Valeur |
|-------|--------|
| **Integration name** | `Fail2ban Logs` |
| **Log file path** | `/var/log/fail2ban.log` |
| **Dataset name** | `fail2ban` |
| **Data stream namespace** | `security` |

**Advanced options:**
```yaml
# Processors (ajouter dans l'UI)
processors:
  - add_fields:
      target: ''
      fields:
        log_type: fail2ban
        environment: production
```

### 2.2 Custom Logs Integration (pour Asterisk)

```
Add integration → Custom Logs
```

| Champ | Valeur |
|-------|--------|
| **Integration name** | `Asterisk Security Logs` |
| **Log file paths** | `/var/log/asterisk/security`<br>`/var/log/asterisk/messages`<br>`/var/log/asterisk/full` |
| **Dataset name** | `asterisk` |
| **Data stream namespace** | `security` |
| **Exclude lines** | `^\[.*\] DEBUG`<br>`^\[.*\] VERBOSE` |

**Multiline settings:**
```yaml
multiline:
  type: pattern
  pattern: '^\['
  negate: true
  match: after
```

**Processors:**
```yaml
processors:
  - add_fields:
      target: ''
      fields:
        log_type: asterisk
        environment: production
```

### 2.3 System Integration (pour Auth/SSH)

```
Add integration → System
→ Enable "System logs"
```

**Configuration:**
- ✅ **Collect logs from auth/secure**
- ✅ **Syslog logs**

**Paths:**
- `/var/log/auth.log` (Debian/Ubuntu)
- `/var/log/secure` (RHEL/CentOS)

**Processors:**
```yaml
processors:
  - add_fields:
      target: ''
      fields:
        log_type: auth
        environment: production
  - drop_event:
      when:
        contains:
          message: "CRON"
```

---

## 📋 Étape 3: Créer Ingest Pipelines (Parsing)

Dans Kibana Dev Tools:

### 3.1 Pipeline Fail2ban

```json
PUT _ingest/pipeline/logs-fail2ban-security
{
  "description": "Parse fail2ban logs with GeoIP enrichment",
  "processors": [
    {
      "grok": {
        "field": "message",
        "patterns": [
          "%{TIMESTAMP_ISO8601:timestamp}%{SPACE}%{DATA:fail2ban_logger}%{SPACE}\\[%{NUMBER:pid}\\]:%{SPACE}%{WORD:log_level}%{SPACE}\\[%{DATA:jail}\\]%{SPACE}%{WORD:action}%{SPACE}%{IP:attacker_ip}",
          "%{TIMESTAMP_ISO8601:timestamp}%{SPACE}%{DATA:fail2ban_logger}%{SPACE}\\[%{NUMBER:pid}\\]:%{SPACE}%{WORD:log_level}%{SPACE}\\[%{DATA:jail}\\]%{SPACE}Unban%{SPACE}%{IP:attacker_ip}"
        ],
        "ignore_failure": true
      }
    },
    {
      "lowercase": {
        "field": "action",
        "ignore_missing": true
      }
    },
    {
      "set": {
        "if": "ctx.action == 'ban'",
        "field": "event.type",
        "value": "banned"
      }
    },
    {
      "set": {
        "if": "ctx.action == 'ban'",
        "field": "event.severity",
        "value": "high"
      }
    },
    {
      "geoip": {
        "field": "attacker_ip",
        "target_field": "geoip",
        "ignore_missing": true
      }
    },
    {
      "geoip": {
        "field": "attacker_ip",
        "target_field": "geoip_asn",
        "database_file": "GeoLite2-ASN.mmdb",
        "ignore_missing": true
      }
    },
    {
      "date": {
        "field": "timestamp",
        "formats": ["ISO8601", "yyyy-MM-dd HH:mm:ss,SSS"],
        "target_field": "@timestamp"
      }
    },
    {
      "remove": {
        "field": ["message", "timestamp"],
        "ignore_missing": true
      }
    }
  ]
}
```

### 3.2 Pipeline Asterisk

```json
PUT _ingest/pipeline/logs-asterisk-security
{
  "description": "Parse Asterisk security logs with GeoIP",
  "processors": [
    {
      "grok": {
        "field": "message",
        "patterns": [
          "\\[%{TIMESTAMP_ISO8601:timestamp}\\]%{SPACE}SECURITY\\[%{NUMBER:thread_id}\\]%{SPACE}%{DATA:source_file}:%{SPACE}Registration from '%{DATA:sip_uri}' failed for '%{IP:attacker_ip}:%{NUMBER:port}' - %{GREEDYDATA:failure_reason}",
          "\\[%{TIMESTAMP_ISO8601:timestamp}\\]%{SPACE}NOTICE\\[%{NUMBER:thread_id}\\]%{SPACE}%{DATA:source_file}:%{SPACE}Registration from '%{DATA:sip_uri}' failed for '%{IP:attacker_ip}:%{NUMBER:port}' - %{GREEDYDATA:failure_reason}",
          "\\[%{TIMESTAMP_ISO8601:timestamp}\\]%{SPACE}SECURITY\\[%{NUMBER:thread_id}\\]%{SPACE}%{DATA:source_file}:%{SPACE}SecurityEvent=\"%{WORD:security_event}\",%{GREEDYDATA:security_details}"
        ],
        "ignore_failure": true
      }
    },
    {
      "kv": {
        "if": "ctx.security_details != null",
        "field": "security_details",
        "field_split": ",",
        "value_split": "=",
        "target_field": "security_event_details",
        "ignore_failure": true
      }
    },
    {
      "grok": {
        "if": "ctx.security_event_details?.RemoteAddress != null",
        "field": "security_event_details.RemoteAddress",
        "patterns": ["IPV4/(UDP|TCP)/%{IP:attacker_ip}/%{NUMBER:port}"],
        "ignore_failure": true
      }
    },
    {
      "set": {
        "if": "ctx.security_event != null || ctx.failure_reason != null",
        "field": "event.type",
        "value": "asterisk_attack_attempt"
      }
    },
    {
      "set": {
        "if": "ctx.security_event =~ /InvalidPassword|FailedACL|InvalidAccountID/",
        "field": "event.severity",
        "value": "high"
      }
    },
    {
      "geoip": {
        "field": "attacker_ip",
        "target_field": "geoip",
        "ignore_missing": true
      }
    },
    {
      "geoip": {
        "field": "attacker_ip",
        "target_field": "geoip_asn",
        "database_file": "GeoLite2-ASN.mmdb",
        "ignore_missing": true
      }
    },
    {
      "date": {
        "field": "timestamp",
        "formats": ["ISO8601"],
        "target_field": "@timestamp"
      }
    },
    {
      "remove": {
        "field": ["message", "timestamp"],
        "ignore_missing": true
      }
    }
  ]
}
```

### 3.3 Pipeline Auth/SSH

```json
PUT _ingest/pipeline/logs-auth-security
{
  "description": "Parse SSH/Auth logs",
  "processors": [
    {
      "grok": {
        "field": "message",
        "patterns": [
          "%{SYSLOGTIMESTAMP:timestamp}%{SPACE}%{HOSTNAME:hostname}%{SPACE}sshd\\[%{NUMBER:pid}\\]:%{SPACE}Failed password for %{USER:username} from %{IP:attacker_ip} port %{NUMBER:port} ssh2",
          "%{SYSLOGTIMESTAMP:timestamp}%{SPACE}%{HOSTNAME:hostname}%{SPACE}sshd\\[%{NUMBER:pid}\\]:%{SPACE}Invalid user %{USER:username} from %{IP:attacker_ip} port %{NUMBER:port}",
          "%{SYSLOGTIMESTAMP:timestamp}%{SPACE}%{HOSTNAME:hostname}%{SPACE}sshd\\[%{NUMBER:pid}\\]:%{SPACE}Accepted %{WORD:auth_method} for %{USER:username} from %{IP:source_ip} port %{NUMBER:port} ssh2"
        ],
        "ignore_failure": true
      }
    },
    {
      "set": {
        "if": "ctx.message?.contains('Failed password') || ctx.message?.contains('Invalid user')",
        "field": "event.type",
        "value": "ssh_failed_auth"
      }
    },
    {
      "set": {
        "if": "ctx.message?.contains('Failed password') || ctx.message?.contains('Invalid user')",
        "field": "event.severity",
        "value": "high"
      }
    },
    {
      "set": {
        "if": "ctx.message?.contains('Accepted')",
        "field": "event.type",
        "value": "ssh_successful_auth"
      }
    },
    {
      "geoip": {
        "field": "attacker_ip",
        "target_field": "geoip",
        "ignore_missing": true
      }
    },
    {
      "geoip": {
        "field": "attacker_ip",
        "target_field": "geoip_asn",
        "database_file": "GeoLite2-ASN.mmdb",
        "ignore_missing": true
      }
    },
    {
      "date": {
        "field": "timestamp",
        "formats": ["MMM  d HH:mm:ss", "MMM dd HH:mm:ss"],
        "target_field": "@timestamp"
      }
    }
  ]
}
```

---

## 📋 Étape 4: Associer Pipelines aux Integrations

Dans Fleet, éditer chaque integration:

### Fail2ban Integration
```
Settings → Advanced options
→ Custom configurations

pipeline: logs-fail2ban-security
```

### Asterisk Integration
```
Settings → Advanced options

pipeline: logs-asterisk-security
```

### System Integration (Auth logs)
```
Settings → Advanced options

pipeline: logs-auth-security
```

---

## 📋 Étape 5: Installer Elastic Agent sur NUCs

### 5.1 Obtenir commande d'installation

```
Fleet → Agents → Add agent
→ Sélectionner policy: "Security Monitoring - NUCs"
→ Copier la commande
```

**Exemple de commande:**
```bash
curl -L -O https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-8.10.2-linux-x86_64.tar.gz
tar xzvf elastic-agent-8.10.2-linux-x86_64.tar.gz
cd elastic-agent-8.10.2-linux-x86_64
sudo ./elastic-agent install \
  --url=https://your-fleet-server:8220 \
  --enrollment-token=YOUR_TOKEN \
  --fleet-server-es=https://your-elasticsearch:9200
```

### 5.2 Sur NUC1

```bash
# SSH vers NUC1
ssh user@nuc1

# Exécuter la commande Fleet (copié de l'étape 5.1)
# L'agent s'installe et s'enregistre automatiquement

# Vérifier
sudo elastic-agent status
```

### 5.3 Sur NUC2

Répéter l'étape 5.2

### 5.4 Vérifier dans Fleet

```
Fleet → Agents
→ Voir NUC1 et NUC2 "Healthy" ✅
```

---

## 📋 Étape 6: Créer Index Template & ILM

Les data streams Elastic Agent créent automatiquement les index, mais tu peux optimiser:

```json
PUT _index_template/logs-security-monitoring
{
  "index_patterns": ["logs-*-security*"],
  "priority": 500,
  "template": {
    "settings": {
      "index.lifecycle.name": "security-logs-policy",
      "number_of_shards": 1,
      "number_of_replicas": 0
    },
    "mappings": {
      "properties": {
        "attacker_ip": { "type": "ip" },
        "source_ip": { "type": "ip" },
        "geoip.location": { "type": "geo_point" },
        "jail": { "type": "keyword" },
        "event.type": { "type": "keyword" },
        "event.severity": { "type": "keyword" }
      }
    }
  }
}
```

**ILM Policy** (même que avant):
```bash
./scripts/setup-elasticsearch.sh
```

---

## 📋 Étape 7: Dashboards Kibana

Les dashboards fonctionnent pareil, mais adapter les index patterns:

**Au lieu de:** `security-logs-*`
**Utiliser:** `logs-*-security*`

Ou créer via le script en modifiant l'index pattern:

```bash
# Éditer setup-kibana-dashboards.sh
# Remplacer: security-logs-*
# Par: logs-*-security*

./scripts/setup-kibana-dashboards.sh
```

---

## 🔍 Queries Adaptées

```lucene
# Fail2ban bans
data_stream.dataset:fail2ban AND action:ban

# Asterisk attacks
data_stream.dataset:asterisk AND (failure_reason:* OR security_event:*)

# SSH failures
data_stream.dataset:system.auth AND event.type:ssh_failed_auth

# Toutes les attaques
event.type:(banned OR asterisk_attack_attempt OR ssh_failed_auth)

# Par NUC
host.name:"nuc1" OR host.name:"nuc2"
```

---

## ✅ Avantages Elastic Agent vs Filebeat

| Feature | Elastic Agent | Filebeat |
|---------|---------------|----------|
| **Configuration** | UI Fleet (facile) | Fichiers YAML |
| **Gestion** | Centralisée | Manuelle |
| **Updates** | Auto via Fleet | Manuelles |
| **Monitoring** | Intégré | Séparé |
| **Parsing** | Ingest Pipelines | Logstash |
| **GeoIP** | Natif ES | Logstash |

---

## 🎯 Résumé Configuration

```
1. Fleet → Create policy "Security Monitoring - NUCs"
2. Add integration "Custom Logs" (fail2ban)
3. Add integration "Custom Logs" (asterisk)
4. Add integration "System" (auth logs)
5. Create Ingest Pipelines (3x)
6. Associate pipelines to integrations
7. Install Elastic Agent on NUC1/NUC2
8. Create dashboards with index pattern: logs-*-security*
9. Done! ✅
```

---

## 🧪 Test

```bash
# Sur NUC1, générer log test
sudo fail2ban-client set sshd banip 1.2.3.4

# Attendre 30 secondes

# Dans Kibana Discover
data_stream.dataset:fail2ban AND attacker_ip:1.2.3.4

# Devrait voir l'événement avec:
# - GeoIP (pays)
# - event.type: banned
# - event.severity: high
```

---

## 📚 Documentation

- [Elastic Agent Guide](https://www.elastic.co/guide/en/fleet/8.10/index.html)
- [Fleet Management](https://www.elastic.co/guide/en/fleet/8.10/fleet-overview.html)
- [Ingest Pipelines](https://www.elastic.co/guide/en/elasticsearch/reference/8.10/ingest.html)

---

**Prochaine étape:** Je te crée les scripts adaptés pour Elastic Agent ?
