# Elastic Security & SIEM - Guide Complet

**Version Elastic Stack:** 8.19.10 / 9.2.4
**Date:** 2025-01-27
**Couverture:** Elastic Security, SIEM, Threat Detection, Incident Response, Threat Hunting

---

## 📑 Table des Matières

1. [Introduction Elastic Security](#introduction-elastic-security)
2. [Architecture SIEM](#architecture-siem)
3. [Configuration Initiale](#configuration-initiale)
4. [Detection Rules](#detection-rules)
5. [Threat Hunting](#threat-hunting)
6. [Case Management](#case-management)
7. [Timeline & Investigation](#timeline--investigation)
8. [Intégrations Sécurité](#intégrations-sécurité)
9. [MITRE ATT&CK Framework](#mitre-attck-framework)
10. [Alerting Sécurité](#alerting-sécurité)
11. [Threat Intelligence](#threat-intelligence)
12. [Incident Response Playbooks](#incident-response-playbooks)

---

## 🛡️ Introduction Elastic Security

### Qu'est-ce qu'Elastic Security ?

Elastic Security est une plateforme unifiée de sécurité qui combine :

```
┌─────────────────────────────────────────────────────────┐
│              Elastic Security Platform                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌────────────────┐  ┌────────────────┐               │
│  │     SIEM       │  │  Endpoint      │               │
│  │                │  │  Security      │               │
│  │ - Log Analysis │  │ - EDR          │               │
│  │ - Correlation  │  │ - Prevention   │               │
│  │ - Detection    │  │ - Response     │               │
│  └────────────────┘  └────────────────┘               │
│                                                         │
│  ┌────────────────┐  ┌────────────────┐               │
│  │ Cloud Native   │  │   Network      │               │
│  │ Security       │  │   Monitoring   │               │
│  │                │  │                │               │
│  │ - K8s Security │  │ - Packet       │               │
│  │ - Container    │  │   Analysis     │               │
│  └────────────────┘  └────────────────┘               │
│                                                         │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────┐
        │   Unified Security Timeline    │
        │   - All events in one view     │
        │   - Correlation across sources │
        │   - Investigation workspace    │
        └────────────────────────────────┘
```

### Fonctionnalités Clés

**1. SIEM (Security Information and Event Management)**
- Collecte et analyse logs de sécurité
- Détection de menaces en temps réel
- Corrélation d'événements multi-sources
- Alerting automatisé

**2. Endpoint Detection & Response (EDR)**
- Protection endpoints (Elastic Agent)
- Détection comportementale
- Response automatisée
- Isolation endpoints compromise

**3. Threat Hunting**
- Interface de recherche avancée
- KQL (Kibana Query Language)
- Timeline pour investigation
- Pivot sur événements suspects

**4. Case Management**
- Gestion incidents
- Workflows investigation
- Collaboration équipe
- Tracking résolution

**5. Detection Engineering**
- 1000+ règles pré-configurées
- Custom rules (KQL, EQL, ML)
- MITRE ATT&CK mapping
- Exception management

---

## 🏗️ Architecture SIEM

### Architecture Complète

```
┌─────────────────────────────────────────────────────────┐
│                    Data Sources                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐            │
│  │ Systems  │  │ Network  │  │   Apps   │            │
│  │          │  │          │  │          │            │
│  │ - Linux  │  │ - Palo   │  │ - Web    │            │
│  │ - Windows│  │ - Cisco  │  │ - API    │            │
│  │ - MacOS  │  │ - F5     │  │ - DB     │            │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘            │
│       │             │              │                   │
└───────┼─────────────┼──────────────┼───────────────────┘
        │             │              │
        └─────────────┴──────────────┘
                      │
        ┌─────────────▼──────────────┐
        │      Data Collection       │
        │                            │
        │  ┌────────────────────┐   │
        │  │  Elastic Agent     │   │
        │  │  - System logs     │   │
        │  │  - Auditd          │   │
        │  │  - Osquery         │   │
        │  │  - Endpoint events │   │
        │  └────────────────────┘   │
        │                            │
        │  ┌────────────────────┐   │
        │  │  Fleet Server      │   │
        │  │  - Policy mgmt     │   │
        │  │  - Agent updates   │   │
        │  └────────────────────┘   │
        └────────────┬───────────────┘
                     │
        ┌────────────▼───────────────┐
        │    Elasticsearch Cluster   │
        │                            │
        │  Indices:                  │
        │  - logs-*                  │
        │  - metrics-*               │
        │  - .siem-signals-*         │
        │  - .alerts-security.*      │
        │  - .lists-*                │
        │  - threat-intel-*          │
        └────────────┬───────────────┘
                     │
        ┌────────────▼───────────────┐
        │   Security Detection       │
        │   Engine                   │
        │                            │
        │  - Detection Rules         │
        │  - Machine Learning Jobs   │
        │  - Anomaly Detection       │
        │  - Threat Intelligence     │
        └────────────┬───────────────┘
                     │
        ┌────────────▼───────────────┐
        │   Kibana Security UI       │
        │                            │
        │  - Alerts Dashboard        │
        │  - Timeline                │
        │  - Cases                   │
        │  - Detection Rules Mgmt    │
        │  - Threat Hunting          │
        └────────────────────────────┘
```

### Flux de Détection

```
1. DATA COLLECTION
   ↓
   Elastic Agent collecte événements (logs, metrics, endpoint events)
   ↓
2. NORMALIZATION
   ↓
   ECS (Elastic Common Schema) - Format standardisé
   ↓
3. ENRICHMENT
   ↓
   - GeoIP
   - Threat Intelligence
   - User/Asset context
   ↓
4. DETECTION
   ↓
   Detection Engine exécute règles
   - Query-based (KQL)
   - EQL (Event Query Language)
   - Machine Learning
   - Indicator Match (IOC)
   ↓
5. ALERT GENERATION
   ↓
   Signal créé si match
   - Severity: critical, high, medium, low
   - MITRE ATT&CK tags
   - Risk score
   ↓
6. TRIAGE & INVESTIGATION
   ↓
   Analyste SOC review dans Timeline
   ↓
7. RESPONSE
   ↓
   - Create Case
   - Isolate endpoint
   - Block IP
   - Custom actions
   ↓
8. DOCUMENTATION
   ↓
   Case Management - Tracking résolution
```

---

## ⚙️ Configuration Initiale

### 1. Activation Elastic Security

**Via Kibana UI:**
```
1. Ouvrir Kibana: https://localhost:5601
2. Menu → Security → Get started
3. Click "Add Elastic Agent"
4. Suivre wizard configuration
```

**Via API:**

```bash
#!/bin/bash
# scripts/setup-elastic-security.sh

set -euo pipefail

KIBANA_URL="https://localhost:5601"

echo "🛡️  Setting up Elastic Security"

# 1. Activer Elastic Security app
curl -X POST "${KIBANA_URL}/api/fleet/setup" \
    -u elastic:${ELASTIC_PASSWORD} \
    --cacert secrets/certs/ca/ca.crt \
    -H 'kbn-xsrf: true' \
    -H 'Content-Type: application/json'

# 2. Créer Security policy
POLICY_RESPONSE=$(curl -s -X POST "${KIBANA_URL}/api/fleet/agent_policies" \
    -u elastic:${ELASTIC_PASSWORD} \
    --cacert secrets/certs/ca/ca.crt \
    -H 'kbn-xsrf: true' \
    -H 'Content-Type: application/json' -d'{
        "name": "Elastic Security Policy",
        "description": "Default security policy with endpoint protection",
        "namespace": "default",
        "monitoring_enabled": ["logs", "metrics"]
    }')

POLICY_ID=$(echo "$POLICY_RESPONSE" | jq -r '.item.id')

# 3. Ajouter Endpoint Security integration
curl -X POST "${KIBANA_URL}/api/fleet/package_policies" \
    -u elastic:${ELASTIC_PASSWORD} \
    --cacert secrets/certs/ca/ca.crt \
    -H 'kbn-xsrf: true' \
    -H 'Content-Type: application/json' -d"{
        \"name\": \"endpoint-security-1\",
        \"description\": \"Endpoint Security integration\",
        \"namespace\": \"default\",
        \"policy_id\": \"${POLICY_ID}\",
        \"enabled\": true,
        \"package\": {
            \"name\": \"endpoint\",
            \"version\": \"8.19.10\"
        },
        \"inputs\": [{
            \"type\": \"endpoint\",
            \"enabled\": true,
            \"streams\": [],
            \"config\": {
                \"policy\": {
                    \"value\": {
                        \"windows\": {
                            \"events\": {
                                \"process\": true,
                                \"network\": true,
                                \"file\": true,
                                \"registry\": true,
                                \"dns\": true
                            },
                            \"malware\": {
                                \"mode\": \"prevent\"
                            },
                            \"ransomware\": {
                                \"mode\": \"prevent\"
                            }
                        },
                        \"mac\": {
                            \"events\": {
                                \"process\": true,
                                \"network\": true,
                                \"file\": true
                            },
                            \"malware\": {
                                \"mode\": \"prevent\"
                            }
                        },
                        \"linux\": {
                            \"events\": {
                                \"process\": true,
                                \"network\": true,
                                \"file\": true
                            },
                            \"malware\": {
                                \"mode\": \"prevent\"
                            }
                        }
                    }
                }
            }
        }]
    }"

echo "✅ Elastic Security configured"
echo "Policy ID: ${POLICY_ID}"
echo "Next: Enroll agents with this policy"
```

### 2. Configuration ECS (Elastic Common Schema)

Tous les logs doivent être mappés au format ECS pour fonctionner avec SIEM.

**Exemple transformation custom logs → ECS:**

```yaml
# logstash/pipeline/security-ecs.conf
input {
  file {
    path => "/var/log/custom-app/security.log"
    start_position => "beginning"
    codec => json
  }
}

filter {
  # Parse custom format vers ECS
  mutate {
    rename => {
      "user" => "[user][name]"
      "src_ip" => "[source][ip]"
      "dst_ip" => "[destination][ip]"
      "action" => "[event][action]"
    }
  }

  # Ajouter champs ECS obligatoires
  mutate {
    add_field => {
      "[event][kind]" => "event"
      "[event][category]" => "authentication"
      "[event][type]" => "info"
      "[event][dataset]" => "custom-app.security"
    }
  }

  # GeoIP enrichment
  geoip {
    source => "[source][ip]"
    target => "[source][geo]"
  }

  # User agent parsing
  useragent {
    source => "[user_agent][original]"
    target => "[user_agent]"
  }

  # Timestamp normalization
  date {
    match => ["timestamp", "ISO8601"]
    target => "@timestamp"
  }
}

output {
  elasticsearch {
    hosts => ["${ELASTICSEARCH_HOST_PORT}"]
    user => "${ELASTIC_USERNAME}"
    password => "${ELASTIC_PASSWORD}"
    ssl => true
    cacert => "/certs/ca.crt"
    ssl_verification_mode => "certificate"

    # Index avec data stream ECS
    index => "logs-custom-app.security-default"
    action => "create"
  }
}
```

### 3. Configuration Detection Engine

**Activer detection engine:**

```bash
# Via Kibana API
curl -X POST "https://localhost:5601/api/detection_engine/index" \
    -u elastic:${ELASTIC_PASSWORD} \
    --cacert secrets/certs/ca/ca.crt \
    -H 'kbn-xsrf: true' \
    -H 'Content-Type: application/json'
```

---

## 🔍 Detection Rules

### Types de Règles

#### 1. Query-Based Rules (KQL)

**Exemple: Détection brute force SSH**

```json
{
  "name": "SSH Brute Force Attempt",
  "description": "Détecte plusieurs échecs d'authentification SSH en peu de temps",
  "severity": "high",
  "risk_score": 73,
  "type": "query",
  "query": "event.category:authentication and event.outcome:failure and event.dataset:system.auth and source.ip:* and user.name:*",
  "index": ["logs-system.auth-*", "filebeat-*"],
  "interval": "5m",
  "from": "now-6m",
  "to": "now",
  "threshold": {
    "field": ["source.ip", "user.name"],
    "value": 5
  },
  "filters": [],
  "threat": [
    {
      "framework": "MITRE ATT&CK",
      "tactic": {
        "id": "TA0006",
        "name": "Credential Access",
        "reference": "https://attack.mitre.org/tactics/TA0006/"
      },
      "technique": [
        {
          "id": "T1110",
          "name": "Brute Force",
          "reference": "https://attack.mitre.org/techniques/T1110/"
        }
      ]
    }
  ],
  "actions": [
    {
      "group": "default",
      "id": "slack-connector-id",
      "params": {
        "message": "🚨 SSH Brute Force detected from {{context.signals.source.ip}}"
      }
    }
  ]
}
```

**Créer via API:**

```bash
curl -X POST "https://localhost:5601/api/detection_engine/rules" \
    -u elastic:${ELASTIC_PASSWORD} \
    --cacert secrets/certs/ca/ca.crt \
    -H 'kbn-xsrf: true' \
    -H 'Content-Type: application/json' \
    -d @ssh-bruteforce-rule.json
```

#### 2. EQL Rules (Event Query Language)

**Exemple: Process injection detection**

```json
{
  "name": "Process Injection via CreateRemoteThread",
  "description": "Détecte tentative d'injection de code dans un processus",
  "severity": "critical",
  "risk_score": 90,
  "type": "eql",
  "language": "eql",
  "query": "sequence by process.entity_id with maxspan=1m\n  [process where event.type == \"start\"]\n  [api where process.Ext.api.name == \"CreateRemoteThread\"]",
  "index": ["logs-endpoint.events.*"],
  "interval": "5m",
  "threat": [
    {
      "framework": "MITRE ATT&CK",
      "tactic": {
        "id": "TA0005",
        "name": "Defense Evasion"
      },
      "technique": [
        {
          "id": "T1055",
          "name": "Process Injection"
        }
      ]
    }
  ]
}
```

#### 3. Machine Learning Rules

**Exemple: Anomaly detection - Network traffic**

```json
{
  "name": "Anomalous Network Traffic Volume",
  "description": "Détecte volume anormal de trafic réseau via ML",
  "severity": "medium",
  "risk_score": 50,
  "type": "machine_learning",
  "machine_learning_job_id": "network_traffic_anomaly",
  "anomaly_threshold": 75,
  "interval": "15m"
}
```

**Créer ML job:**

```bash
# Via Kibana ML interface ou API
curl -X PUT "https://localhost:9200/_ml/anomaly_detectors/network_traffic_anomaly" \
    -u elastic:${ELASTIC_PASSWORD} \
    --cacert secrets/certs/ca/ca.crt \
    -H 'Content-Type: application/json' -d'{
        "analysis_config": {
            "bucket_span": "15m",
            "detectors": [
                {
                    "detector_description": "High network traffic",
                    "function": "high_count",
                    "by_field_name": "source.ip"
                }
            ],
            "influencers": ["source.ip", "destination.ip"]
        },
        "data_description": {
            "time_field": "@timestamp"
        }
    }'
```

#### 4. Indicator Match Rules (Threat Intelligence)

**Exemple: IOC matching**

```json
{
  "name": "Known Malicious IP Communication",
  "description": "Détecte communication avec IP malveillante connue",
  "severity": "critical",
  "risk_score": 99,
  "type": "threat_match",
  "query": "destination.ip:* or source.ip:*",
  "threat_query": "threat.indicator.ip:*",
  "threat_index": ["threat-intel-*"],
  "threat_mapping": [
    {
      "entries": [
        {
          "field": "destination.ip",
          "type": "mapping",
          "value": "threat.indicator.ip"
        }
      ]
    },
    {
      "entries": [
        {
          "field": "source.ip",
          "type": "mapping",
          "value": "threat.indicator.ip"
        }
      ]
    }
  ],
  "threat_filters": [
    {
      "term": {
        "threat.indicator.type": "ipv4-addr"
      }
    }
  ]
}
```

### Règles Pré-configurées

Elastic Security inclut **1000+ règles** pré-configurées couvrant :

**Catégories principales:**
- Initial Access (T1189, T1190, T1133...)
- Execution (T1059, T1053, T1203...)
- Persistence (T1053, T1136, T1543...)
- Privilege Escalation (T1068, T1134, T1548...)
- Defense Evasion (T1070, T1112, T1218...)
- Credential Access (T1003, T1110, T1555...)
- Discovery (T1046, T1057, T1082...)
- Lateral Movement (T1021, T1047, T1210...)
- Collection (T1005, T1039, T1113...)
- Exfiltration (T1020, T1041, T1048...)
- Impact (T1485, T1486, T1490...)

**Activer toutes les règles:**

```bash
#!/bin/bash
# scripts/enable-all-detection-rules.sh

KIBANA_URL="https://localhost:5601"

# Récupérer toutes les règles pré-packagées
curl -X POST "${KIBANA_URL}/api/detection_engine/rules/_bulk_action" \
    -u elastic:${ELASTIC_PASSWORD} \
    --cacert secrets/certs/ca/ca.crt \
    -H 'kbn-xsrf: true' \
    -H 'Content-Type: application/json' -d'{
        "action": "enable",
        "query": "alert.attributes.tags: \"Elastic\""
    }'

echo "✅ All Elastic detection rules enabled"
```

### Custom Rules Examples

#### Détection Crypto Mining

```json
{
  "name": "Cryptocurrency Mining Activity",
  "description": "Détecte activité de crypto mining basée sur process et network patterns",
  "severity": "medium",
  "risk_score": 47,
  "type": "query",
  "query": "(process.name:(xmrig or cgminer or ethminer or claymore) or network.protocol:stratum)",
  "index": ["logs-endpoint.events.*", "logs-network.*"],
  "threat": [
    {
      "framework": "MITRE ATT&CK",
      "tactic": {
        "id": "TA0040",
        "name": "Impact"
      },
      "technique": [
        {
          "id": "T1496",
          "name": "Resource Hijacking"
        }
      ]
    }
  ]
}
```

#### Détection Web Shell

```json
{
  "name": "Web Shell Execution",
  "description": "Détecte exécution de web shell via patterns suspects",
  "severity": "high",
  "risk_score": 80,
  "type": "eql",
  "query": "process where event.type == \"start\" and\n  process.parent.name:(\"w3wp.exe\" or \"apache*\" or \"nginx\" or \"httpd\") and\n  process.name:(\"cmd.exe\" or \"powershell.exe\" or \"sh\" or \"bash\" or \"python*\")",
  "index": ["logs-endpoint.events.*"],
  "threat": [
    {
      "framework": "MITRE ATT&CK",
      "tactic": {
        "id": "TA0003",
        "name": "Persistence"
      },
      "technique": [
        {
          "id": "T1505.003",
          "name": "Web Shell"
        }
      ]
    }
  ]
}
```

#### Détection Data Exfiltration

```json
{
  "name": "Large Data Transfer to External IP",
  "description": "Détecte transfert anormal de données vers IP externe",
  "severity": "high",
  "risk_score": 75,
  "type": "threshold",
  "query": "destination.ip:* and not destination.ip:(10.0.0.0/8 or 172.16.0.0/12 or 192.168.0.0/16) and network.bytes:*",
  "threshold": {
    "field": "source.ip",
    "value": 1,
    "cardinality": [
      {
        "field": "network.bytes",
        "value": 100000000
      }
    ]
  },
  "threat": [
    {
      "framework": "MITRE ATT&CK",
      "tactic": {
        "id": "TA0010",
        "name": "Exfiltration"
      },
      "technique": [
        {
          "id": "T1041",
          "name": "Exfiltration Over C2 Channel"
        }
      ]
    }
  ]
}
```

---

## 🔎 Threat Hunting

### Interface Timeline

Timeline est l'outil principal pour threat hunting dans Elastic Security.

**Fonctionnalités:**
- Recherche KQL avancée
- Corrélation événements
- Pivot sur entités (IP, user, process)
- Sauvegarde investigations
- Partage avec équipe

**Exemple Hunting Query:**

```
Rechercher activité suspecte utilisateur:

event.category:process and user.name:admin and
  (process.name:cmd.exe or process.name:powershell.exe) and
  event.action:start and
  process.parent.name:explorer.exe
```

**Queries de Hunting Communes:**

```bash
# 1. Processus rares exécutés
event.category:process and event.action:start
| rare process.name by host.name

# 2. Connexions réseau inhabituelles
event.category:network and event.action:connection_attempted
| rare destination.ip by source.ip

# 3. Modifications registry Windows
event.category:registry and event.action:modification
| where registry.path like "%Run%" or registry.path like "%Startup%"

# 4. Privilèges élevés inattendus
event.category:process and process.Ext.token.integrity_level_name:"System"
| where not process.executable like "C:\\Windows\\System32\\%"

# 5. Anomalies temporelles (activité hors heures)
event.category:authentication and event.outcome:success
| where hour(@timestamp) < 6 or hour(@timestamp) > 22
```

### Hunting Workflows

#### Workflow 1: Compromission Suspectée

```
1. POINT DE DÉPART
   └─ Alert: "Suspicious PowerShell Activity"

2. PIVOT SUR USER
   user.name:"john.doe"
   └─ Timeline: Tous événements utilisateur last 24h

3. PIVOT SUR HOST
   host.name:"DESKTOP-ABC123"
   └─ Timeline: Tous processus sur ce host

4. PIVOT SUR NETWORK
   source.ip:"10.0.1.50"
   └─ Timeline: Toutes connexions depuis cet IP

5. ANALYSE LATERAL MOVEMENT
   destination.ip:* and source.ip:"10.0.1.50"
   └─ Identifier autres hosts compromis

6. CREATE CASE
   Documenter findings, actions prises
```

#### Workflow 2: IOC Investigation

```
1. IOC FOURNI
   └─ IP: 198.51.100.10 (suspect)

2. RECHERCHE HISTORIQUE
   destination.ip:"198.51.100.10" or source.ip:"198.51.100.10"
   └─ Last 30 days

3. IDENTIFIER ASSETS AFFECTÉS
   | stats count by host.name, user.name

4. ANALYSE PATTERNS
   - Fréquence connexions
   - Volume données transférées
   - Processus initiateurs

5. EXPANSION INVESTIGATION
   - Autres IOCs associés (domains, hashes)
   - Recherche dans threat intelligence

6. REMEDIATION
   - Block IP firewall
   - Isolate compromised hosts
   - Reset credentials
```

---

## 📋 Case Management

### Création Case

**Via UI Kibana:**
```
Security → Cases → Create new case
```

**Via API:**

```bash
curl -X POST "https://localhost:5601/api/cases" \
    -u elastic:${ELASTIC_PASSWORD} \
    --cacert secrets/certs/ca/ca.crt \
    -H 'kbn-xsrf: true' \
    -H 'Content-Type: application/json' -d'{
        "title": "Suspected Data Exfiltration - User john.doe",
        "description": "Large volume of data transferred to external IP 198.51.100.10",
        "tags": ["data-exfiltration", "critical", "user-john-doe"],
        "severity": "high",
        "connector": {
            "id": "none",
            "name": "none",
            "type": ".none",
            "fields": null
        },
        "settings": {
            "syncAlerts": true
        },
        "owner": "securitySolution"
    }'
```

### Workflow Case

```
1. CASE CREATION
   └─ Titre, Description, Severity, Tags

2. INVESTIGATION
   └─ Ajouter Timeline
   └─ Ajouter Signals (alerts)
   └─ Documenter findings

3. COLLABORATION
   └─ Assign à analyste
   └─ Commentaires équipe
   └─ Update status

4. REMEDIATION
   └─ Actions taken
   └─ Blocklist updates
   └─ Patches applied

5. POST-MORTEM
   └─ Root cause analysis
   └─ Lessons learned
   └─ Preventive measures

6. CLOSURE
   └─ Final report
   └─ Mark resolved
   └─ Archive
```

### Intégration SOAR

**Connecter à SOAR (ServiceNow, JIRA, etc.):**

```bash
# Créer connector ServiceNow
curl -X POST "https://localhost:5601/api/actions/connector" \
    -u elastic:${ELASTIC_PASSWORD} \
    --cacert secrets/certs/ca/ca.crt \
    -H 'kbn-xsrf: true' \
    -H 'Content-Type: application/json' -d'{
        "connector_type_id": ".servicenow",
        "name": "ServiceNow Incident",
        "config": {
            "apiUrl": "https://instance.service-now.com",
            "isOAuth": false
        },
        "secrets": {
            "username": "admin",
            "password": "password"
        }
    }'

# Configurer case pour auto-create tickets
curl -X POST "https://localhost:5601/api/cases/configure" \
    -u elastic:${ELASTIC_PASSWORD} \
    --cacert secrets/certs/ca/ca.crt \
    -H 'kbn-xsrf: true' \
    -H 'Content-Type: application/json' -d'{
        "connector": {
            "id": "servicenow-connector-id",
            "name": "ServiceNow Incident",
            "type": ".servicenow",
            "fields": {
                "impact": "2",
                "severity": "2",
                "urgency": "2"
            }
        },
        "closure_type": "close-by-user",
        "owner": "securitySolution"
    }'
```

---

## 🧩 Intégrations Sécurité

### 1. Windows Event Logs

**Configuration Winlogbeat/Elastic Agent:**

```yaml
- name: winlog-security
  type: winlog
  data_stream:
    dataset: windows.security
  streams:
    - id: winlog-security
      enabled: true
      data_stream:
        dataset: windows.security
      vars:
        channel: Security
        event_id: >-
          4624, 4625, 4634, 4648, 4672, 4688, 4698, 4720, 4722, 4724, 4728,
          4732, 4738, 4740, 4756, 4768, 4769, 4771, 4776, 4778, 4779, 4798, 5140
        ignore_older: 72h
```

**Événements Windows critiques:**
- `4624` - Account logon
- `4625` - Account logon failure
- `4672` - Special privileges assigned
- `4688` - Process creation
- `4698` - Scheduled task created
- `4720` - User account created
- `4732` - Member added to security group
- `4768/4769` - Kerberos TGT/TGS
- `5140` - Network share accessed

### 2. Linux Auditd

**Configuration auditd rules:**

```bash
# /etc/audit/rules.d/elastic-security.rules

# Monitor file changes
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k privilege_escalation

# Monitor process execution
-a always,exit -F arch=b64 -S execve -k process_execution

# Monitor network connections
-a always,exit -F arch=b64 -S socket -S connect -k network_connections

# Monitor privilege escalation
-a always,exit -F arch=b64 -S setuid -S setgid -k privilege_changes

# Monitor kernel modules
-w /sbin/insmod -p x -k kernel_modules
-w /sbin/rmmod -p x -k kernel_modules
-w /sbin/modprobe -p x -k kernel_modules
```

**Elastic Agent integration:**

```yaml
- name: auditd-logs
  type: auditd
  data_stream:
    dataset: auditd.log
  streams:
    - id: auditd-logs
      enabled: true
      data_stream:
        dataset: auditd.log
      vars:
        socket_type: unicast
        resolve_ids: true
```

### 3. Palo Alto Firewall

**Configuration syslog forwarding:**

```xml
<syslog>
  <entry name="elastic-security">
    <server>
      <entry name="elastic-logstash">
        <server>logstash.example.com</server>
        <transport>TCP</transport>
        <port>5514</port>
        <format>BSD</format>
        <facility>LOG_LOCAL0</facility>
      </entry>
    </server>
    <format>
      <threat>true</threat>
      <traffic>true</traffic>
      <url>true</url>
      <wildfire>true</wildfire>
    </format>
  </entry>
</syslog>
```

**Logstash pipeline:**

```ruby
input {
  tcp {
    port => 5514
    type => "paloalto"
  }
}

filter {
  if [type] == "paloalto" {
    csv {
      source => "message"
      columns => [
        "future_use1","receive_time","serial","type","threat_content_type",
        "future_use2","generated_time","src_ip","dst_ip","nat_src_ip","nat_dst_ip",
        "rule","src_user","dst_user","app","vsys","src_zone","dst_zone",
        "inbound_if","outbound_if","log_action","future_use3","session_id",
        "repeat_cnt","src_port","dst_port","nat_src_port","nat_dst_port","flags",
        "protocol","action","bytes","bytes_sent","bytes_received","packets",
        "start_time","elapsed_time","category","future_use4","seqno","actionflags",
        "src_country","dst_country","future_use5","packets_sent","packets_received",
        "session_end_reason","device_group_hierarchy1","device_group_hierarchy2",
        "device_group_hierarchy3","device_group_hierarchy4","vsys_name","device_name",
        "action_source"
      ]
    }

    # Map to ECS
    mutate {
      add_field => {
        "[event][kind]" => "event"
        "[event][category]" => "network"
        "[event][type]" => "connection"
        "[event][dataset]" => "paloalto.firewall"
      }
      rename => {
        "src_ip" => "[source][ip]"
        "dst_ip" => "[destination][ip]"
        "src_port" => "[source][port]"
        "dst_port" => "[destination][port]"
        "action" => "[event][action]"
      }
    }

    # GeoIP enrichment
    geoip {
      source => "[source][ip]"
      target => "[source][geo]"
    }
    geoip {
      source => "[destination][ip]"
      target => "[destination][geo]"
    }
  }
}

output {
  elasticsearch {
    hosts => ["${ELASTICSEARCH_HOST_PORT}"]
    index => "logs-paloalto.firewall-default"
    # ... auth config
  }
}
```

### 4. Osquery Integration

**Deploy osquery via Elastic Agent:**

```yaml
- name: osquery-manager
  type: osquery
  data_stream:
    dataset: osquery_manager.result
  streams:
    - id: osquery-queries
      enabled: true
      data_stream:
        dataset: osquery_manager.result
      vars:
        interval: 3600
        queries:
          - query: >-
              SELECT * FROM users WHERE username != 'root' AND shell != '/usr/sbin/nologin'
            id: suspicious_users
            description: Users with login shells
          - query: >-
              SELECT * FROM processes WHERE name LIKE '%nc%' OR name LIKE '%netcat%'
            id: netcat_processes
            description: Detect netcat usage
          - query: >-
              SELECT * FROM listening_ports WHERE port NOT IN (22, 80, 443)
            id: unusual_listening_ports
            description: Non-standard listening ports
```

---

## 🎯 MITRE ATT&CK Framework

### Mapping avec Elastic Security

Elastic Security mappe automatiquement chaque détection au framework MITRE ATT&CK.

**Dashboard MITRE ATT&CK:**
```
Security → Detection & Response → MITRE ATT&CK
```

**Visualisation:**
- Heatmap des techniques détectées
- Timeline des tactiques
- Coverage analysis

**Exemple règle avec MITRE mapping:**

```json
{
  "threat": [
    {
      "framework": "MITRE ATT&CK",
      "tactic": {
        "id": "TA0002",
        "name": "Execution",
        "reference": "https://attack.mitre.org/tactics/TA0002/"
      },
      "technique": [
        {
          "id": "T1059",
          "name": "Command and Scripting Interpreter",
          "reference": "https://attack.mitre.org/techniques/T1059/",
          "subtechnique": [
            {
              "id": "T1059.001",
              "name": "PowerShell",
              "reference": "https://attack.mitre.org/techniques/T1059/001/"
            }
          ]
        }
      ]
    },
    {
      "framework": "MITRE ATT&CK",
      "tactic": {
        "id": "TA0005",
        "name": "Defense Evasion",
        "reference": "https://attack.mitre.org/tactics/TA0005/"
      },
      "technique": [
        {
          "id": "T1140",
          "name": "Deobfuscate/Decode Files or Information",
          "reference": "https://attack.mitre.org/techniques/T1140/"
        }
      ]
    }
  ]
}
```

### Coverage Report

**Générer rapport coverage:**

```bash
#!/bin/bash
# scripts/generate-mitre-coverage.sh

KIBANA_URL="https://localhost:5601"

# Récupérer toutes les règles actives
RULES=$(curl -s "${KIBANA_URL}/api/detection_engine/rules/_find?per_page=10000" \
    -u elastic:${ELASTIC_PASSWORD} \
    --cacert secrets/certs/ca/ca.crt)

# Parser MITRE tactics/techniques
echo "$RULES" | jq -r '.data[] | select(.enabled == true) | .threat[] | "\(.tactic.name):\(.technique[].name)"' | \
    sort | uniq -c | sort -rn > mitre-coverage-report.txt

echo "✅ MITRE ATT&CK Coverage Report generated"
cat mitre-coverage-report.txt
```

---

## 🚨 Alerting Sécurité

### Configuration Multi-Canal

#### 1. Email Alerts

```bash
# Créer email connector
curl -X POST "https://localhost:5601/api/actions/connector" \
    -u elastic:${ELASTIC_PASSWORD} \
    --cacert secrets/certs/ca/ca.crt \
    -H 'kbn-xsrf: true' \
    -H 'Content-Type: application/json' -d'{
        "connector_type_id": ".email",
        "name": "Security Alerts Email",
        "config": {
            "service": "gmail",
            "from": "security-alerts@example.com",
            "host": "smtp.gmail.com",
            "port": 587,
            "secure": false
        },
        "secrets": {
            "user": "security-alerts@example.com",
            "password": "app-password-here"
        }
    }'
```

#### 2. Slack Alerts

```bash
# Créer Slack connector
curl -X POST "https://localhost:5601/api/actions/connector" \
    -u elastic:${ELASTIC_PASSWORD} \
    --cacert secrets/certs/ca/ca.crt \
    -H 'kbn-xsrf: true' \
    -H 'Content-Type: application/json' -d'{
        "connector_type_id": ".slack",
        "name": "Security Alerts Slack",
        "config": {
            "webhookUrl": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
        }
    }'
```

#### 3. PagerDuty Integration

```bash
# Créer PagerDuty connector
curl -X POST "https://localhost:5601/api/actions/connector" \
    -u elastic:${ELASTIC_PASSWORD} \
    --cacert secrets/certs/ca/ca.crt \
    -H 'kbn-xsrf: true' \
    -H 'Content-Type: application/json' -d'{
        "connector_type_id": ".pagerduty",
        "name": "Security Incidents PagerDuty",
        "config": {
            "apiUrl": "https://api.pagerduty.com"
        },
        "secrets": {
            "routingKey": "YOUR_INTEGRATION_KEY"
        }
    }'
```

### Alert Routing par Severity

```bash
# Règle: Critical → PagerDuty + Email
# Règle: High → Slack + Email
# Règle: Medium → Slack only
# Règle: Low → Log only

# Configuration dans detection rule:
"actions": [
    {
        "group": "default",
        "id": "pagerduty-connector-id",
        "params": {
            "severity": "critical",
            "eventAction": "trigger",
            "summary": "{{context.rule.name}}: {{context.alerts.length}} alerts"
        },
        "frequency": {
            "summary": true,
            "notifyWhen": "onActiveAlert",
            "throttle": null
        }
    },
    {
        "group": "default",
        "id": "email-connector-id",
        "params": {
            "to": ["soc@example.com", "security-team@example.com"],
            "subject": "🚨 CRITICAL ALERT: {{context.rule.name}}",
            "message": "Alert Details:\n\nRule: {{context.rule.name}}\nSeverity: {{context.rule.severity}}\nAlerts: {{context.alerts.length}}\n\nInvestigate in Kibana: {{context.kibanaBaseUrl}}/app/security/alerts"
        }
    }
]
```

---

## 🔗 Threat Intelligence

### Intégration Threat Feeds

#### 1. AbuseCH Feeds

```bash
#!/bin/bash
# scripts/import-threat-intel.sh

KIBANA_URL="https://localhost:5601"

# Download AbuseCH URLhaus feed
curl -s https://urlhaus.abuse.ch/downloads/csv_recent/ | \
  tail -n +10 | \
  awk -F ',' '{
    if ($4 != "") {
      printf "{\"threat\":{\"indicator\":{\"type\":\"url\",\"url\":\"%s\",\"provider\":\"abuse.ch\",\"first_seen\":\"%s\"}},\"event\":{\"kind\":\"enrichment\",\"category\":\"threat\",\"type\":\"indicator\"}}\n", $4, $2
    }
  }' | \
  while read line; do
    curl -s -X POST "https://localhost:9200/threat-intel-urlhaus/_doc" \
      -u elastic:${ELASTIC_PASSWORD} \
      --cacert secrets/certs/ca/ca.crt \
      -H 'Content-Type: application/json' \
      -d "$line"
  done

echo "✅ URLhaus threat feed imported"
```

#### 2. MISP Integration

```bash
# Configurer MISP connector
curl -X POST "${KIBANA_URL}/api/threat_intelligence/indicators/_import" \
    -u elastic:${ELASTIC_PASSWORD} \
    --cacert secrets/certs/ca/ca.crt \
    -H 'kbn-xsrf: true' \
    -H 'Content-Type: application/json' -d'{
        "source": "misp",
        "config": {
            "url": "https://misp.example.com",
            "api_key": "YOUR_MISP_API_KEY",
            "verify_ssl": true
        },
        "types": ["ip", "domain", "url", "hash"],
        "tags": ["malware", "c2"],
        "interval": "1h"
    }'
```

#### 3. Custom Threat Intel

```bash
# Importer liste IPs malveillantes
cat malicious-ips.txt | while read ip; do
  curl -X POST "https://localhost:9200/threat-intel-custom/_doc" \
    -u elastic:${ELASTIC_PASSWORD} \
    --cacert secrets/certs/ca/ca.crt \
    -H 'Content-Type: application/json' -d"{
      \"threat\": {
        \"indicator\": {
          \"type\": \"ipv4-addr\",
          \"ip\": \"$ip\",
          \"provider\": \"internal\",
          \"confidence\": \"high\",
          \"first_seen\": \"$(date -Iseconds)\"
        }
      },
      \"event\": {
        \"kind\": \"enrichment\",
        \"category\": \"threat\",
        \"type\": \"indicator\"
      },
      \"tags\": [\"malicious\", \"blocked\"]
    }"
done
```

---

## 📖 Incident Response Playbooks

### Playbook 1: Malware Detection

```
1. ALERT RECEIVED
   └─ Detection: "Malware Execution Detected"
   └─ Severity: Critical
   └─ Host: DESKTOP-ABC123
   └─ User: john.doe

2. IMMEDIATE ACTIONS (< 5 min)
   ✓ Isolate endpoint via Elastic Agent
     curl -X POST "${KIBANA_URL}/api/endpoint/action/isolate" \
       -d '{"endpoint_ids": ["endpoint-id"]}'

   ✓ Disable user account
   ✓ Block hash in firewall/EDR

3. INVESTIGATION (5-30 min)
   ✓ Timeline analysis - Process tree
   ✓ Check persistence mechanisms
   ✓ Network connections analysis
   ✓ File modifications review

4. CONTAINMENT (30-60 min)
   ✓ Identify other infected hosts
   ✓ Block C2 domains/IPs
   ✓ Quarantine malware samples
   ✓ Reset compromised credentials

5. ERADICATION (1-4 hours)
   ✓ Remove malware from all hosts
   ✓ Patch vulnerabilities exploited
   ✓ Update detection rules
   ✓ Scan network for IOCs

6. RECOVERY (4-24 hours)
   ✓ Restore from clean backups
   ✓ Un-isolate endpoints
   ✓ Re-enable accounts
   ✓ Monitor for re-infection

7. POST-INCIDENT (1-3 days)
   ✓ Root cause analysis
   ✓ Update runbooks
   ✓ Train users
   ✓ Close case with report
```

### Playbook 2: Data Exfiltration

```
1. ALERT RECEIVED
   └─ Detection: "Large Data Transfer to External IP"
   └─ Severity: High
   └─ Source: 10.0.1.50
   └─ Destination: 198.51.100.10
   └─ Volume: 10 GB

2. IMMEDIATE ACTIONS (< 5 min)
   ✓ Block destination IP at firewall
   ✓ Preserve network logs
   ✓ Identify source host/user

3. INVESTIGATION (5-30 min)
   ✓ What data was accessed?
   ✓ How was it exfiltrated? (protocol, tool)
   ✓ Duration of exfiltration
   ✓ Other destinations contacted?

4. CONTAINMENT (30-60 min)
   ✓ Isolate source host
   ✓ Disable user account
   ✓ Block all suspicious IPs
   ✓ Enable DLP rules

5. FORENSICS (1-8 hours)
   ✓ Disk imaging
   ✓ Memory dump analysis
   ✓ Log correlation
   ✓ Determine scope of breach

6. NOTIFICATION (< 24 hours)
   ✓ Legal team notification
   ✓ Compliance team (GDPR, etc.)
   ✓ Affected parties if required
   ✓ Law enforcement if necessary

7. RECOVERY & HARDENING (1-7 days)
   ✓ Implement DLP solution
   ✓ Network segmentation review
   ✓ Access control hardening
   ✓ Monitoring enhancement
```

### Playbook 3: Ransomware

```
1. ALERT RECEIVED
   └─ Detection: "Ransomware Activity Detected"
   └─ Severity: Critical
   └─ Multiple hosts affected

2. IMMEDIATE ACTIONS (< 2 min)
   ✓ ISOLATE ALL AFFECTED HOSTS IMMEDIATELY
   ✓ Disable network shares
   ✓ Disconnect backup systems
   ✓ Activate incident response team

3. ASSESSMENT (2-10 min)
   ✓ Number of hosts impacted
   ✓ Ransomware variant identification
   ✓ Entry point determination
   ✓ Spread mechanism

4. CONTAINMENT (10-30 min)
   ✓ Network segmentation
   ✓ Disable compromised accounts
   ✓ Block C2 communications
   ✓ Preserve evidence

5. ERADICATION (DO NOT PAY RANSOM)
   ✓ Identify patient zero
   ✓ Remove ransomware from all systems
   ✓ Patch entry point vulnerability
   ✓ Update all credentials

6. RECOVERY (1-7 days)
   ✓ Restore from offline backups
   ✓ Verify backup integrity
   ✓ Rebuild compromised systems
   ✓ Phased return to operations

7. POST-INCIDENT (1-2 weeks)
   ✓ Security assessment
   ✓ Backup strategy review
   ✓ Security awareness training
   ✓ Implement ransomware-specific defenses
```

---

## 📊 Dashboards SIEM

### Dashboard Security Overview

**Widgets principaux:**
- Alert volume timeline
- Top alerts by severity
- MITRE ATT&CK heatmap
- Top attackers (source IPs)
- Top targets (destination hosts)
- Alert status (open/closed)
- Mean time to respond (MTTR)

**Création via Saved Object:**

```json
{
  "attributes": {
    "title": "Security Overview Dashboard",
    "hits": 0,
    "description": "High-level security monitoring",
    "panelsJSON": "[...]",
    "optionsJSON": "{\"hidePanelTitles\":false,\"useMargins\":true}",
    "version": 1,
    "timeRestore": true,
    "timeTo": "now",
    "timeFrom": "now-24h",
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"query\":{\"language\":\"kuery\",\"query\":\"\"},\"filter\":[]}"
    }
  },
  "type": "dashboard"
}
```

### Dashboard Network Security

**Focus sur:**
- Network traffic patterns
- Denied connections
- Geographic distribution (GeoIP)
- Protocol analysis
- Port scanning detection
- Lateral movement indicators

---

## ✅ Checklist Déploiement SIEM

### Setup Initial
- [ ] ✅ Elastic Security activé dans Kibana
- [ ] ✅ Detection Engine configuré
- [ ] ✅ Fleet Server déployé
- [ ] ✅ Elastic Agents enrollés (endpoints)
- [ ] ✅ Logs sources configurés (Windows, Linux, Network)

### Detection Rules
- [ ] ✅ Règles pré-packagées activées (1000+)
- [ ] ✅ Custom rules créées (use case spécifiques)
- [ ] ✅ Machine Learning jobs configurés
- [ ] ✅ Threat Intelligence feeds intégrés
- [ ] ✅ Exception lists configurées

### Alerting
- [ ] ✅ Connectors configurés (Email, Slack, PagerDuty)
- [ ] ✅ Alert routing par severity
- [ ] ✅ Notification preferences équipe
- [ ] ✅ Escalation procedures documentées

### Investigation
- [ ] ✅ Timeline templates créés
- [ ] ✅ Hunting queries sauvegardées
- [ ] ✅ Case management configuré
- [ ] ✅ SOAR integration (si applicable)

### Threat Intelligence
- [ ] ✅ Threat feeds importés (AbuseCH, MISP, etc.)
- [ ] ✅ Custom IOCs ajoutés
- [ ] ✅ Indicator match rules créées
- [ ] ✅ Automatic TI updates configurés

### Response
- [ ] ✅ Playbooks documentés
- [ ] ✅ Endpoint isolation testée
- [ ] ✅ Automated response actions configurées
- [ ] ✅ Backup/restore procedures validées

### Monitoring
- [ ] ✅ Dashboards SIEM créés
- [ ] ✅ Detection rule health monitoring
- [ ] ✅ Alert volume trends tracked
- [ ] ✅ MTTR (Mean Time To Respond) tracked

### Documentation
- [ ] ✅ Runbooks écrits
- [ ] ✅ Équipe formée
- [ ] ✅ On-call schedule défini
- [ ] ✅ Contact lists à jour

---

## 📚 Ressources

### Documentation Officielle
- [Elastic Security](https://www.elastic.co/guide/en/security/current/index.html)
- [Detection Rules](https://www.elastic.co/guide/en/security/current/detection-engine-overview.html)
- [SIEM Guide](https://www.elastic.co/guide/en/security/current/siem-guide.html)
- [Endpoint Security](https://www.elastic.co/guide/en/security/current/install-endpoint.html)

### Threat Intelligence Sources
- [Abuse.ch](https://abuse.ch/)
- [MISP](https://www.misp-project.org/)
- [AlienVault OTX](https://otx.alienvault.com/)
- [VirusTotal](https://www.virustotal.com/)

### MITRE ATT&CK
- [MITRE ATT&CK Framework](https://attack.mitre.org/)
- [ATT&CK Navigator](https://mitre-attack.github.io/attack-navigator/)

### Community
- [Elastic Security Forums](https://discuss.elastic.co/c/security/)
- [Detection Rules Repo](https://github.com/elastic/detection-rules)

---

**Document créé:** 2025-01-27
**Auteur:** Claude (Anthropic)
**Version:** 1.0.0
**Prochaine révision:** Trimestrielle

---

## 🎯 Résumé

Elastic Security SIEM offre une plateforme complète de détection et réponse aux menaces avec :

- **🔍 Detection:** 1000+ règles pré-configurées + custom rules
- **🎯 Threat Hunting:** Timeline pour investigations avancées
- **📋 Case Management:** Workflow incident response complet
- **🔗 Integrations:** Windows, Linux, Network, Cloud, EDR
- **🎨 MITRE ATT&CK:** Mapping automatique des techniques
- **🚨 Alerting:** Multi-canal (Email, Slack, PagerDuty)
- **🧠 Threat Intelligence:** Feeds externes + custom IOCs
- **📖 Playbooks:** Incident response documenté

**Production-ready SIEM en quelques heures avec cette documentation !** 🛡️
