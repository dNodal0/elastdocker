# Sécurité Avancée, APM Server & Fleet Server - Guide Complet

**Version Elastic Stack:** 8.19.10 / 9.2.4
**Date:** 2025-01-27
**Couverture:** Security, APM, Fleet Server, Elastic Agent, Integrations

---

## 📑 Table des Matières

1. [Sécurité Avancée](#sécurité-avancée)
2. [APM Server Configuration](#apm-server-configuration)
3. [Fleet Server & Elastic Agent](#fleet-server--elastic-agent)
4. [RBAC & Users Management](#rbac--users-management)
5. [API Keys Management](#api-keys-management)
6. [Audit Logging](#audit-logging)
7. [Intégrations Modernes](#intégrations-modernes)
8. [Monitoring & Observability](#monitoring--observability)

---

## 🔒 Sécurité Avancée

### 1. Architecture de Sécurité Multicouche

```
┌─────────────────────────────────────────────────────────┐
│                    Load Balancer / WAF                  │
│                  (Cloudflare, AWS ALB)                  │
└────────────────────┬────────────────────────────────────┘
                     │ HTTPS/TLS 1.3
┌────────────────────▼────────────────────────────────────┐
│                 Reverse Proxy (Nginx)                   │
│        - Rate Limiting                                  │
│        - IP Whitelisting                                │
│        - DDoS Protection                                │
│        - SSL Termination                                │
└────────────────────┬────────────────────────────────────┘
                     │ Internal TLS
┌────────────────────▼────────────────────────────────────┐
│              Elasticsearch Cluster                      │
│        - Transport SSL (node-to-node)                   │
│        - HTTP SSL (client connections)                  │
│        - RBAC + API Keys                                │
│        - Audit Logging                                  │
│        - Field/Document Level Security                  │
└─────────────────────────────────────────────────────────┘
```

### 2. Configuration SSL/TLS Avancée

#### 2.1 Génération Certificats Production

**Script de génération avec SAN (Subject Alternative Names):**

```bash
#!/bin/bash
# scripts/generate-production-certs.sh

set -euo pipefail

CERTS_DIR="./secrets/certs"
CA_DIR="${CERTS_DIR}/ca"
DAYS_VALID=365

# Domaines et IPs
DOMAINS="elasticsearch.example.com,kibana.example.com,*.example.com"
IPS="10.0.1.10,10.0.1.11,10.0.1.12"

echo "🔐 Generating Production SSL Certificates"

# 1. CA privée
openssl genrsa -out "${CA_DIR}/ca.key" 4096

# 2. CA certificate (10 ans)
openssl req -new -x509 -sha256 \
  -key "${CA_DIR}/ca.key" \
  -out "${CA_DIR}/ca.crt" \
  -days 3650 \
  -subj "/C=FR/ST=IDF/L=Paris/O=MyCompany/OU=IT/CN=Elasticsearch CA"

# 3. Elasticsearch certificate avec SAN
cat > "${CERTS_DIR}/elasticsearch/openssl.cnf" <<EOF
[req]
default_bits = 4096
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = FR
ST = IDF
L = Paris
O = MyCompany
OU = IT
CN = elasticsearch.example.com

[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = elasticsearch
DNS.2 = elasticsearch.example.com
DNS.3 = *.elasticsearch.example.com
DNS.4 = localhost
IP.1 = 127.0.0.1
IP.2 = 10.0.1.10
EOF

# 4. Générer clé privée Elasticsearch
openssl genrsa -out "${CERTS_DIR}/elasticsearch/elasticsearch.key" 4096

# 5. CSR (Certificate Signing Request)
openssl req -new \
  -key "${CERTS_DIR}/elasticsearch/elasticsearch.key" \
  -out "${CERTS_DIR}/elasticsearch/elasticsearch.csr" \
  -config "${CERTS_DIR}/elasticsearch/openssl.cnf"

# 6. Signer avec CA
openssl x509 -req \
  -in "${CERTS_DIR}/elasticsearch/elasticsearch.csr" \
  -CA "${CA_DIR}/ca.crt" \
  -CAkey "${CA_DIR}/ca.key" \
  -CAcreateserial \
  -out "${CERTS_DIR}/elasticsearch/elasticsearch.crt" \
  -days ${DAYS_VALID} \
  -sha256 \
  -extfile "${CERTS_DIR}/elasticsearch/openssl.cnf" \
  -extensions v3_req

# 7. Vérifier certificat
openssl x509 -in "${CERTS_DIR}/elasticsearch/elasticsearch.crt" -text -noout

# 8. Répéter pour Kibana, Logstash, APM, Fleet
# ...

echo "✅ Certificates generated successfully"
echo "📁 Location: ${CERTS_DIR}"
echo "⏰ Valid for: ${DAYS_VALID} days"
```

#### 2.2 Configuration TLS Moderne (TLS 1.3)

**elasticsearch.yml:**
```yaml
## Transport Layer Security (node-to-node)
xpack.security.transport.ssl.enabled: true
xpack.security.transport.ssl.verification_mode: full
xpack.security.transport.ssl.key: certs/elasticsearch.key
xpack.security.transport.ssl.certificate: certs/elasticsearch.crt
xpack.security.transport.ssl.certificate_authorities: certs/ca.crt
xpack.security.transport.ssl.supported_protocols: ["TLSv1.3", "TLSv1.2"]
xpack.security.transport.ssl.cipher_suites:
  - TLS_AES_256_GCM_SHA384
  - TLS_AES_128_GCM_SHA256
  - TLS_CHACHA20_POLY1305_SHA256

## HTTP Layer Security (client connections)
xpack.security.http.ssl.enabled: true
xpack.security.http.ssl.verification_mode: certificate
xpack.security.http.ssl.key: certs/elasticsearch.key
xpack.security.http.ssl.certificate: certs/elasticsearch.crt
xpack.security.http.ssl.certificate_authorities: certs/ca.crt
xpack.security.http.ssl.client_authentication: optional
xpack.security.http.ssl.supported_protocols: ["TLSv1.3", "TLSv1.2"]
xpack.security.http.ssl.cipher_suites:
  - TLS_AES_256_GCM_SHA384
  - TLS_AES_128_GCM_SHA256
  - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
  - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
```

#### 2.3 Rotation Automatique des Certificats

**Script de rotation:** `scripts/rotate-certificates.sh`

```bash
#!/bin/bash
# Rotation automatique des certificats SSL avant expiration

set -euo pipefail

CERTS_DIR="./secrets/certs"
DAYS_BEFORE_EXPIRY=30
BACKUP_DIR="./secrets/certs_backup_$(date +%Y%m%d)"

# Fonction pour vérifier expiration
check_expiry() {
    local cert_file=$1
    local expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
    local expiry_epoch=$(date -d "$expiry_date" +%s)
    local current_epoch=$(date +%s)
    local days_remaining=$(( ($expiry_epoch - $current_epoch) / 86400 ))

    echo "$days_remaining"
}

# Vérifier tous les certificats
for cert in "${CERTS_DIR}"/*/*.crt; do
    days_remaining=$(check_expiry "$cert")

    if [[ $days_remaining -lt $DAYS_BEFORE_EXPIRY ]]; then
        echo "⚠️  Certificate $cert expires in $days_remaining days"
        echo "🔄 Initiating rotation..."

        # Backup ancien certificat
        mkdir -p "$BACKUP_DIR"
        cp -r "$CERTS_DIR" "$BACKUP_DIR/"

        # Régénérer certificats
        ./scripts/generate-production-certs.sh

        # Reload Elasticsearch (rolling restart)
        docker exec elasticsearch bin/elasticsearch-keystore add-file \
            xpack.security.http.ssl.certificate \
            /usr/share/elasticsearch/config/certs/elasticsearch.crt --force

        # Trigger reload sans redémarrage (si supporté)
        curl -X POST "https://localhost:9200/_nodes/reload_secure_settings" \
            -u elastic:${ELASTIC_PASSWORD} \
            --cacert "${CERTS_DIR}/ca/ca.crt"

        echo "✅ Certificate rotated successfully"
    else
        echo "✓ Certificate $cert valid for $days_remaining days"
    fi
done

# Cron: 0 0 * * 0 /path/to/rotate-certificates.sh >> /var/log/cert-rotation.log 2>&1
```

---

### 3. RBAC (Role-Based Access Control)

#### 3.1 Architecture des Rôles

```
┌─────────────────────────────────────────────────────────┐
│                    Built-in Roles                       │
├─────────────────────────────────────────────────────────┤
│ superuser         │ Full cluster access                 │
│ kibana_admin      │ Full Kibana access                  │
│ monitoring_user   │ Read monitoring data                │
│ ingest_admin      │ Manage ingest pipelines             │
│ viewer            │ Read-only Kibana                    │
└─────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────┐
│                    Custom Roles                         │
├─────────────────────────────────────────────────────────┤
│ logs_readonly     │ Read logs-* indices                 │
│ metrics_writer    │ Write metrics-* indices             │
│ security_analyst  │ Investigate security events         │
│ developer         │ Dev environment access              │
└─────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────┐
│                   Role Mappings                         │
├─────────────────────────────────────────────────────────┤
│ LDAP/AD Groups    │ → Custom Roles                      │
│ SAML Attributes   │ → Custom Roles                      │
│ API Keys          │ → Specific Roles                    │
└─────────────────────────────────────────────────────────┘
```

#### 3.2 Création de Rôles Personnalisés

**Via API REST:**

```bash
# Rôle: Lecture seule logs FreqTrade
curl -X POST "https://localhost:9200/_security/role/freqtrade_logs_reader" \
  -u elastic:${ELASTIC_PASSWORD} \
  --cacert secrets/certs/ca/ca.crt \
  -H 'Content-Type: application/json' -d'
{
  "cluster": ["monitor"],
  "indices": [
    {
      "names": ["logs-freqtrade-*", "freqtrade-logs-*"],
      "privileges": ["read", "view_index_metadata"],
      "field_security": {
        "grant": ["*"],
        "except": ["sensitive_field"]
      },
      "query": "{\"match\": {\"environment\": \"production\"}}"
    }
  ],
  "applications": [
    {
      "application": "kibana-.kibana",
      "privileges": ["feature_discover.read", "feature_dashboard.read"],
      "resources": ["space:default"]
    }
  ],
  "run_as": [],
  "metadata": {
    "version": 1,
    "description": "Read-only access to FreqTrade logs in production"
  }
}'

# Rôle: Écriture métriques APM
curl -X POST "https://localhost:9200/_security/role/apm_metrics_writer" \
  -u elastic:${ELASTIC_PASSWORD} \
  --cacert secrets/certs/ca/ca.crt \
  -H 'Content-Type: application/json' -d'
{
  "cluster": ["monitor", "manage_ilm"],
  "indices": [
    {
      "names": ["metrics-apm*", "traces-apm*"],
      "privileges": ["create_doc", "create_index", "auto_configure"],
      "field_security": {
        "grant": ["*"]
      }
    }
  ],
  "metadata": {
    "description": "Write APM metrics and traces"
  }
}'

# Rôle: Analyste sécurité
curl -X POST "https://localhost:9200/_security/role/security_analyst" \
  -u elastic:${ELASTIC_PASSWORD} \
  --cacert secrets/certs/ca/ca.crt \
  -H 'Content-Type: application/json' -d'
{
  "cluster": ["monitor"],
  "indices": [
    {
      "names": ["logs-*", "metrics-*", ".siem-signals-*"],
      "privileges": ["read", "view_index_metadata", "maintenance"],
      "field_security": {
        "grant": ["*"]
      }
    }
  ],
  "applications": [
    {
      "application": "kibana-.kibana",
      "privileges": [
        "feature_siem.all",
        "feature_securitySolution.all",
        "feature_discover.all"
      ],
      "resources": ["space:security"]
    }
  ],
  "metadata": {
    "description": "Security analyst with SIEM access"
  }
}'
```

#### 3.3 Gestion des Utilisateurs

**Script de création utilisateurs:** `scripts/create-users.sh`

```bash
#!/bin/bash
# Création automatisée d'utilisateurs avec rôles

create_user() {
    local username=$1
    local password=$2
    local roles=$3
    local full_name=$4
    local email=$5

    curl -X POST "https://localhost:9200/_security/user/${username}" \
        -u elastic:${ELASTIC_PASSWORD} \
        --cacert secrets/certs/ca/ca.crt \
        -H 'Content-Type: application/json' -d"{
            \"password\": \"${password}\",
            \"roles\": ${roles},
            \"full_name\": \"${full_name}\",
            \"email\": \"${email}\",
            \"metadata\": {
                \"created_by\": \"automation\",
                \"created_at\": \"$(date -Iseconds)\"
            }
        }"

    echo "✅ User ${username} created"
}

# Utilisateurs par équipe
# DevOps Team
create_user "devops_admin" "$(openssl rand -base64 32)" \
    '["superuser", "kibana_admin"]' \
    "DevOps Administrator" \
    "devops@example.com"

# Development Team
create_user "dev_user" "$(openssl rand -base64 32)" \
    '["developer", "kibana_user"]' \
    "Developer User" \
    "dev@example.com"

# Security Team
create_user "security_analyst" "$(openssl rand -base64 32)" \
    '["security_analyst", "viewer"]' \
    "Security Analyst" \
    "security@example.com"

# Monitoring (read-only)
create_user "monitoring_ro" "$(openssl rand -base64 32)" \
    '["monitoring_user", "viewer"]' \
    "Monitoring Read-Only" \
    "monitoring@example.com"

# FreqTrade Logs Reader
create_user "freqtrade_viewer" "$(openssl rand -base64 32)" \
    '["freqtrade_logs_reader"]' \
    "FreqTrade Logs Viewer" \
    "trading@example.com"

echo "✅ All users created successfully"
echo "📧 Send credentials via secure channel (Vault, 1Password, etc.)"
```

#### 3.4 Document & Field Level Security

**Restriction par document:**

```bash
# Rôle: Accès uniquement à ses propres données
curl -X POST "https://localhost:9200/_security/role/user_own_data" \
  -u elastic:${ELASTIC_PASSWORD} \
  --cacert secrets/certs/ca/ca.crt \
  -H 'Content-Type: application/json' -d'
{
  "indices": [
    {
      "names": ["logs-app-*"],
      "privileges": ["read"],
      "query": "{\"term\": {\"user.id\": \"{{_user.metadata.user_id}}\"}}"
    }
  ]
}'

# Rôle: Masquage champs sensibles
curl -X POST "https://localhost:9200/_security/role/pii_restricted" \
  -u elastic:${ELASTIC_PASSWORD} \
  --cacert secrets/certs/ca/ca.crt \
  -H 'Content-Type: application/json' -d'
{
  "indices": [
    {
      "names": ["logs-*"],
      "privileges": ["read"],
      "field_security": {
        "grant": ["*"],
        "except": [
          "user.email",
          "user.phone",
          "credit_card",
          "ssn",
          "password"
        ]
      }
    }
  ]
}'
```

---

### 4. API Keys Management

#### 4.1 Création d'API Keys

**API Key pour ingestion logs:**

```bash
# Créer API key avec durée limitée
curl -X POST "https://localhost:9200/_security/api_key" \
  -u elastic:${ELASTIC_PASSWORD} \
  --cacert secrets/certs/ca/ca.crt \
  -H 'Content-Type: application/json' -d'
{
  "name": "freqtrade-logs-ingestion",
  "role_descriptors": {
    "freqtrade_writer": {
      "cluster": ["monitor"],
      "indices": [
        {
          "names": ["logs-freqtrade-*"],
          "privileges": ["create_doc", "create_index", "auto_configure"]
        }
      ]
    }
  },
  "expiration": "30d",
  "metadata": {
    "application": "freqtrade",
    "environment": "production",
    "created_by": "devops"
  }
}'

# Réponse:
# {
#   "id": "VuaCfGcBCdbkQm-e5aOx",
#   "name": "freqtrade-logs-ingestion",
#   "api_key": "ui2lp2axTNmsyakw9tvNnw",
#   "encoded": "VnVhQ2ZHY0JDZGJrUW0tZTVhT3g6dWkybHAyYXhUTm1zeWFrdzl0dk5udw=="
# }

# Utilisation:
# Authorization: ApiKey VnVhQ2ZHY0JDZGJrUW0tZTVhT3g6dWkybHAyYXhUTm1zeWFrdzl0dk5udw==
```

**API Key pour APM Agent:**

```bash
curl -X POST "https://localhost:9200/_security/api_key" \
  -u elastic:${ELASTIC_PASSWORD} \
  --cacert secrets/certs/ca/ca.crt \
  -H 'Content-Type: application/json' -d'
{
  "name": "apm-agent-production",
  "role_descriptors": {
    "apm_writer": {
      "cluster": ["monitor", "manage_ilm"],
      "indices": [
        {
          "names": ["traces-apm*", "metrics-apm*", "logs-apm*"],
          "privileges": ["create_doc", "create_index", "auto_configure"]
        }
      ]
    }
  },
  "expiration": "90d",
  "metadata": {
    "application": "apm",
    "service": "trading-api",
    "environment": "production"
  }
}'
```

#### 4.2 Gestion du Cycle de Vie des API Keys

**Script de rotation API Keys:** `scripts/rotate-api-keys.sh`

```bash
#!/bin/bash
# Rotation automatique API keys avant expiration

set -euo pipefail

ES_URL="https://localhost:9200"
DAYS_BEFORE_EXPIRY=7

# Liste toutes les API keys
api_keys=$(curl -s -X GET "${ES_URL}/_security/api_key" \
    -u elastic:${ELASTIC_PASSWORD} \
    --cacert secrets/certs/ca/ca.crt)

# Parser et vérifier expiration
echo "$api_keys" | jq -r '.api_keys[] | select(.expiration != null) | @base64' | \
while IFS= read -r key_b64; do
    key=$(echo "$key_b64" | base64 -d)

    id=$(echo "$key" | jq -r '.id')
    name=$(echo "$key" | jq -r '.name')
    expiration=$(echo "$key" | jq -r '.expiration')

    # Calculer jours restants
    expiry_epoch=$(date -d "$expiration" +%s)
    current_epoch=$(date +%s)
    days_remaining=$(( ($expiry_epoch - $current_epoch) / 86400 ))

    if [[ $days_remaining -lt $DAYS_BEFORE_EXPIRY ]]; then
        echo "⚠️  API Key '$name' expires in $days_remaining days"

        # Récupérer role descriptors originaux
        role_descriptors=$(echo "$key" | jq -c '.role_descriptors')

        # Créer nouvelle API key
        new_key=$(curl -s -X POST "${ES_URL}/_security/api_key" \
            -u elastic:${ELASTIC_PASSWORD} \
            --cacert secrets/certs/ca/ca.crt \
            -H 'Content-Type: application/json' -d"{
                \"name\": \"${name}\",
                \"role_descriptors\": ${role_descriptors},
                \"expiration\": \"90d\",
                \"metadata\": {
                    \"rotated_from\": \"${id}\",
                    \"rotated_at\": \"$(date -Iseconds)\"
                }
            }")

        new_id=$(echo "$new_key" | jq -r '.id')
        new_encoded=$(echo "$new_key" | jq -r '.encoded')

        echo "✅ New API Key created: $new_id"
        echo "📋 New encoded key: $new_encoded"

        # Envoyer notification (Slack, email, etc.)
        send_rotation_notification "$name" "$new_encoded"

        # Invalider ancienne clé après période de grâce (7 jours)
        # curl -X DELETE "${ES_URL}/_security/api_key" \
        #     -u elastic:${ELASTIC_PASSWORD} \
        #     -H 'Content-Type: application/json' -d"{\"ids\": [\"$id\"]}"
    fi
done

# Cron: 0 8 * * * /path/to/rotate-api-keys.sh
```

#### 4.3 Stockage Sécurisé des API Keys

**Intégration HashiCorp Vault:**

```bash
#!/bin/bash
# Stocker API keys dans Vault

export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='your-vault-token'

# Créer API key et stocker dans Vault
create_and_store_api_key() {
    local name=$1
    local path=$2

    # Créer API key
    response=$(curl -s -X POST "https://localhost:9200/_security/api_key" \
        -u elastic:${ELASTIC_PASSWORD} \
        --cacert secrets/certs/ca/ca.crt \
        -H 'Content-Type: application/json' -d"{
            \"name\": \"${name}\",
            \"role_descriptors\": {
                \"writer\": {
                    \"indices\": [{\"names\": [\"logs-*\"], \"privileges\": [\"write\"]}]
                }
            },
            \"expiration\": \"90d\"
        }")

    # Extraire credentials
    api_key=$(echo "$response" | jq -r '.api_key')
    encoded=$(echo "$response" | jq -r '.encoded')

    # Stocker dans Vault
    vault kv put "${path}" \
        api_key="${api_key}" \
        encoded="${encoded}" \
        created_at="$(date -Iseconds)" \
        expires_in="90d"

    echo "✅ API Key stored in Vault: ${path}"
}

# Exemples
create_and_store_api_key "freqtrade-logs" "secret/elasticsearch/freqtrade"
create_and_store_api_key "apm-agent" "secret/elasticsearch/apm"
```

---

## 📊 APM Server Configuration Avancée

### 1. Architecture APM Moderne

```
┌─────────────────────────────────────────────────────────┐
│              Applications (Instrumented)                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │ Node.js  │  │  Python  │  │   Java   │             │
│  │   App    │  │   App    │  │   App    │             │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘             │
│       │             │              │                    │
│       └─────────────┴──────────────┘                    │
│                     │                                   │
│              APM Agent Libraries                        │
└─────────────────────┼───────────────────────────────────┘
                      │ HTTPS/TLS
                      │ Secret Token / API Key
┌─────────────────────▼───────────────────────────────────┐
│                   APM Server                            │
│  ┌────────────────────────────────────────────────┐    │
│  │  - Receive traces, metrics, errors             │    │
│  │  - Validate auth (Secret Token / API Key)      │    │
│  │  - Process & enrich data                       │    │
│  │  - Sampling decisions                          │    │
│  │  - RUM (Real User Monitoring)                  │    │
│  └────────────────────┬───────────────────────────┘    │
└───────────────────────┼─────────────────────────────────┘
                        │ Bulk API
┌───────────────────────▼─────────────────────────────────┐
│              Elasticsearch Cluster                      │
│  ┌────────────────────────────────────────────────┐    │
│  │  Indices:                                       │    │
│  │  - traces-apm-*     (Distributed tracing)      │    │
│  │  - metrics-apm-*    (Application metrics)      │    │
│  │  - logs-apm-*       (Application logs)         │    │
│  │  - apm-*-error-*    (Error tracking)           │    │
│  └────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────┐
│                      Kibana                             │
│  - APM UI (traces visualization)                       │
│  - Service Maps                                        │
│  - Error tracking                                      │
│  - Alerting on metrics/errors                         │
└─────────────────────────────────────────────────────────┘
```

### 2. Configuration APM Server Production

**apm-server/config/apm-server.yml:**

```yaml
#========================= APM Server Configuration =========================

apm-server:
  # Host and port APM Server listens on
  host: "0.0.0.0:8200"

  # Maximum event size in bytes (default: 307200 = 300KB)
  max_event_size: 307200

  # Idle timeout for client connections
  idle_timeout: 45s

  # Read timeout for requests
  read_timeout: 30s

  # Write timeout for responses
  write_timeout: 30s

  # Shutdown timeout
  shutdown_timeout: 30s

  # Maximum duration before releasing resources when shutting down
  max_header_size: 1048576  # 1MB

  #====================== RUM (Real User Monitoring) =======================

  rum:
    enabled: true

    # Event rate limit per IP (requests per second)
    event_rate:
      limit: 300
      lru_size: 1000

    # Allowed origins for CORS (Cross-Origin Resource Sharing)
    allow_origins:
      - "https://app.example.com"
      - "https://dashboard.example.com"

    # Allowed RUM HTTP headers
    allow_headers:
      - "Content-Type"
      - "Content-Encoding"
      - "Accept"

    # Library pattern for source mapping
    library_pattern: "node_modules|bower_components|~"

    # Exclude from error monitoring
    exclude_from_grouping: "^/webpack"

    # Source mapping for stack traces
    source_mapping:
      enabled: true
      cache:
        expiration: 5m
      index_pattern: "apm-*-sourcemap*"

  #========================== API Key Authentication =======================

  # API Key authentication (recommended over secret token)
  api_key:
    enabled: true
    limit: 100  # Max number of unique API keys per minute

  # Secret Token authentication (legacy, use API keys instead)
  secret_token: "${ELASTIC_APM_SECRET_TOKEN}"

  #========================== Jaeger Integration ===========================

  # Support Jaeger agents (distributed tracing compatibility)
  jaeger:
    grpc:
      enabled: false
      host: "localhost:14250"
    http:
      enabled: false
      host: "localhost:14268"

  #========================== Sampling ======================================

  # Tail-based sampling (sample after seeing full trace)
  sampling:
    tail:
      enabled: true
      interval: 10s
      policies:
        # Keep all errors
        - sample_rate: 1.0
          trace.name: ["*error*", "*exception*"]

        # Sample 50% of slow transactions (>1s)
        - sample_rate: 0.5
          trace.outcome: ["success"]
          trace.duration.us:
            gt: 1000000

        # Sample 10% of normal transactions
        - sample_rate: 0.1
          trace.outcome: ["success"]

  #========================== Instrumentation ==============================

  instrumentation:
    enabled: true
    environment: "${ENVIRONMENT:production}"

    # Capture HTTP headers
    capture_headers: true

    # Capture body (careful with sensitive data!)
    capture_body: "errors"  # "off", "errors", "transactions", "all"

  #========================== Data Streams =================================

  data_streams:
    enabled: true
    namespace: "default"

#========================= Elasticsearch Output ==========================

output.elasticsearch:
  hosts: ["${ELASTICSEARCH_HOST_PORT}"]
  protocol: "https"

  # Authentication
  username: "${ELASTIC_USERNAME}"
  password: "${ELASTIC_PASSWORD}"

  # Or use API key (recommended)
  # api_key: "id:api_key"

  # SSL Configuration
  ssl:
    enabled: true
    certificate_authorities: ["/certs/ca.crt"]
    certificate: "/certs/apm-server.crt"
    key: "/certs/apm-server.key"
    verification_mode: "certificate"

  # Performance tuning
  worker: 2
  bulk_max_size: 5120
  timeout: 90

  # Index Lifecycle Management
  ilm:
    enabled: auto

  # Pipeline for additional processing
  pipeline: "apm"

#========================= Kibana Integration ============================

setup.kibana:
  host: "https://${KIBANA_HOST}:${KIBANA_PORT}"
  username: "${ELASTIC_USERNAME}"
  password: "${ELASTIC_PASSWORD}"

  ssl:
    enabled: true
    certificate_authorities: ["/certs/ca.crt"]
    verification_mode: "certificate"

#========================= Logging Configuration =========================

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/apm-server
  name: apm-server
  keepfiles: 7
  permissions: 0640

# JSON logging format
logging.json: true

#========================= Monitoring ====================================

# Self-monitoring
monitoring:
  enabled: true
  elasticsearch:
    hosts: ["${ELASTICSEARCH_HOST_PORT}"]
    username: "${ELASTIC_USERNAME}"
    password: "${ELASTIC_PASSWORD}"
    ssl:
      certificate_authorities: ["/certs/ca.crt"]

#========================= Processors ====================================

# Add custom metadata to all events
processors:
  - add_host_metadata:
      netinfo.enabled: false

  - add_cloud_metadata: ~

  - add_docker_metadata: ~

  # Add custom fields
  - add_fields:
      target: ""
      fields:
        environment: "${ENVIRONMENT:production}"
        datacenter: "${DATACENTER:dc1}"
        service.version: "${SERVICE_VERSION:unknown}"

  # Drop debug events in production
  - drop_event:
      when:
        equals:
          log.level: "debug"
```

### 3. Instrumentation Applications

#### 3.1 Node.js / Express

```javascript
// server.js
const apm = require('elastic-apm-node').start({
  // Service name (unique identifier)
  serviceName: 'freqtrade-api',

  // APM Server URL
  serverUrl: 'https://apm-server.example.com:8200',

  // Authentication (use API key in production)
  apiKey: process.env.ELASTIC_APM_API_KEY,
  // or secret token (legacy)
  // secretToken: process.env.ELASTIC_APM_SECRET_TOKEN,

  // Environment
  environment: process.env.NODE_ENV || 'production',

  // Service version (from package.json or git sha)
  serviceVersion: require('./package.json').version,

  // Transaction sampling rate (0.0 to 1.0)
  transactionSampleRate: 1.0,

  // Capture body for errors
  captureBody: 'errors',

  // Capture headers
  captureHeaders: true,

  // Error log integration
  errorOnAbortedRequests: true,

  // Transaction max spans
  transactionMaxSpans: 500,

  // Log level
  logLevel: 'info',

  // Custom context
  globalLabels: {
    datacenter: 'dc1',
    team: 'trading'
  },

  // SSL verification (disable only in dev!)
  verifyServerCert: true,
  serverCaCertFile: '/path/to/ca.crt'
});

const express = require('express');
const app = express();

// Your app code...
app.get('/api/trades', async (req, res) => {
  // APM automatically traces this endpoint

  // Manual span for database query
  const span = apm.startSpan('Fetch trades from DB');
  try {
    const trades = await db.query('SELECT * FROM trades');
    res.json(trades);
  } catch (error) {
    // Capture error
    apm.captureError(error);
    res.status(500).json({ error: 'Failed to fetch trades' });
  } finally {
    if (span) span.end();
  }
});

// Custom transaction
app.post('/api/analyze', async (req, res) => {
  const transaction = apm.startTransaction('Analysis Job', 'background');

  try {
    // Set custom context
    apm.setLabel('strategy', req.body.strategy);
    apm.setLabel('timeframe', req.body.timeframe);

    // Business logic
    const result = await performAnalysis(req.body);

    res.json(result);
    transaction.result = 'success';
  } catch (error) {
    transaction.result = 'error';
    apm.captureError(error);
    res.status(500).json({ error: error.message });
  } finally {
    transaction.end();
  }
});

app.listen(3000, () => {
  console.log('Server started on port 3000');
});
```

#### 3.2 Python / Django

```python
# settings.py
INSTALLED_APPS = [
    # ...
    'elasticapm.contrib.django',
]

ELASTIC_APM = {
    'SERVICE_NAME': 'freqtrade-bot',
    'SERVER_URL': 'https://apm-server.example.com:8200',

    # Authentication (API Key recommended)
    'API_KEY': os.getenv('ELASTIC_APM_API_KEY'),
    # or Secret Token
    # 'SECRET_TOKEN': os.getenv('ELASTIC_APM_SECRET_TOKEN'),

    'ENVIRONMENT': os.getenv('ENVIRONMENT', 'production'),
    'SERVICE_VERSION': '1.2.3',

    # Transaction sampling
    'TRANSACTION_SAMPLE_RATE': 1.0,

    # Capture body
    'CAPTURE_BODY': 'errors',

    # Capture headers
    'CAPTURE_HEADERS': True,

    # SSL verification
    'VERIFY_SERVER_CERT': True,
    'SERVER_CERT': '/path/to/ca.crt',

    # Custom labels
    'GLOBAL_LABELS': {
        'datacenter': 'dc1',
        'team': 'trading'
    },

    # Django specific
    'DJANGO_TRANSACTION_NAME_FROM_ROUTE': True,

    # Ignore specific URLs
    'TRANSACTIONS_IGNORE_PATTERNS': [
        '^/health',
        '^/metrics',
        '^/static/'
    ],

    # Log integration
    'LOG_LEVEL': 'info',
}

MIDDLEWARE = [
    'elasticapm.contrib.django.middleware.TracingMiddleware',
    # ... other middleware
]

# Usage in code
from elasticapm import capture_span, label, set_custom_context

def process_trading_signal(signal_data):
    # Custom span
    with capture_span('process_signal', span_type='trading'):
        # Add labels
        label(strategy=signal_data['strategy'])
        label(pair=signal_data['pair'])

        # Custom context
        set_custom_context({
            'signal_strength': signal_data['strength'],
            'indicators': signal_data['indicators']
        })

        # Business logic
        result = analyze_signal(signal_data)
        return result
```

#### 3.3 Python / Flask + FreqTrade

```python
# freqtrade_apm.py
from elasticapm import Client
from elasticapm.contrib.flask import ElasticAPM
from flask import Flask

app = Flask(__name__)

# Configure APM
app.config['ELASTIC_APM'] = {
    'SERVICE_NAME': 'freqtrade-bot',
    'SERVER_URL': 'https://apm-server.example.com:8200',
    'API_KEY': os.getenv('ELASTIC_APM_API_KEY'),
    'ENVIRONMENT': 'production',
    'CAPTURE_BODY': 'errors',
    'TRANSACTION_SAMPLE_RATE': 1.0,
    'GLOBAL_LABELS': {
        'bot_id': 'bot1',
        'strategy': 'NFI5MOHO'
    }
}

apm = ElasticAPM(app)

# Manual instrumentation for FreqTrade strategy
class MyStrategy(IStrategy):
    def populate_indicators(self, dataframe, metadata):
        with apm.client.capture_span('populate_indicators', span_type='strategy'):
            # Add custom context
            apm.client.tag(pair=metadata['pair'])

            # Calculate indicators
            dataframe['rsi'] = ta.RSI(dataframe)
            dataframe['ema'] = ta.EMA(dataframe)

            return dataframe

    def populate_entry_trend(self, dataframe, metadata):
        span = apm.client.begin_span('populate_entry_trend', span_type='strategy')
        try:
            apm.client.tag(pair=metadata['pair'])

            # Entry conditions
            dataframe.loc[
                (dataframe['rsi'] < 30) &
                (dataframe['close'] > dataframe['ema']),
                'enter_long'
            ] = 1

            # Count signals
            signals = dataframe['enter_long'].sum()
            apm.client.tag(entry_signals=signals)

            return dataframe
        except Exception as e:
            apm.client.capture_exception()
            raise
        finally:
            apm.client.end_span()
```

### 4. Alerting APM

**Règles d'alerting Kibana:**

```bash
# Alert: High error rate
curl -X POST "https://localhost:5601/api/alerting/rule" \
  -u elastic:${ELASTIC_PASSWORD} \
  --cacert secrets/certs/ca/ca.crt \
  -H 'kbn-xsrf: true' \
  -H 'Content-Type: application/json' -d'
{
  "name": "APM: High Error Rate",
  "rule_type_id": "apm.error_rate",
  "schedule": {
    "interval": "1m"
  },
  "params": {
    "serviceName": "freqtrade-api",
    "environment": "production",
    "threshold": 5,
    "windowSize": 5,
    "windowUnit": "m"
  },
  "actions": [
    {
      "group": "threshold met",
      "id": "slack-connector-id",
      "params": {
        "message": "🚨 High error rate detected in {{context.serviceName}}: {{context.errorRate}} errors/min"
      }
    }
  ]
}'

# Alert: Slow transactions
curl -X POST "https://localhost:5601/api/alerting/rule" \
  -u elastic:${ELASTIC_PASSWORD} \
  --cacert secrets/certs/ca/ca.crt \
  -H 'kbn-xsrf: true' \
  -H 'Content-Type: application/json' -d'
{
  "name": "APM: Slow Transactions",
  "rule_type_id": "apm.transaction_duration",
  "schedule": {
    "interval": "1m"
  },
  "params": {
    "serviceName": "freqtrade-api",
    "transactionType": "request",
    "environment": "production",
    "threshold": 2000,
    "aggregationType": "95th",
    "windowSize": 5,
    "windowUnit": "m"
  },
  "actions": [
    {
      "group": "threshold met",
      "id": "pagerduty-connector-id",
      "params": {
        "severity": "warning",
        "eventAction": "trigger",
        "summary": "Slow transactions detected: {{context.transactionName}} P95={{context.duration}}ms"
      }
    }
  ]
}'
```

---

## 🚀 Fleet Server & Elastic Agent

### 1. Architecture Fleet Server

```
┌─────────────────────────────────────────────────────────┐
│                     Kibana Fleet UI                     │
│  - Policies management                                  │
│  - Agents enrollment                                    │
│  - Integration catalog                                  │
└────────────────────┬────────────────────────────────────┘
                     │ HTTPS
┌────────────────────▼────────────────────────────────────┐
│                   Fleet Server                          │
│  - Agent communication hub                              │
│  - Policy distribution                                  │
│  - Agent check-in                                       │
│  - Artifact hosting                                     │
└────────────────────┬────────────────────────────────────┘
                     │ HTTPS (bidirectional)
          ┌──────────┼──────────┬──────────┐
          │          │          │          │
┌─────────▼──┐  ┌───▼──────┐  ┌▼─────────┐  ┌──────────┐
│ Elastic    │  │ Elastic  │  │ Elastic  │  │ Elastic  │
│ Agent      │  │ Agent    │  │ Agent    │  │ Agent    │
│ (Server 1) │  │(Server 2)│  │(Server 3)│  │(Server n)│
└────────────┘  └──────────┘  └──────────┘  └──────────┘
     │               │              │              │
     └───────────────┴──────────────┴──────────────┘
                     │
                     ▼
          Data sent to Elasticsearch
          (logs, metrics, traces, etc.)
```

### 2. Déploiement Fleet Server

#### 2.1 Configuration Docker

**docker-compose.fleet.yml:**

```yaml
version: '3.8'

services:
  fleet-server:
    image: docker.elastic.co/beats/elastic-agent:${ELK_VERSION}
    container_name: fleet-server
    restart: unless-stopped
    user: root

    environment:
      # Fleet Server configuration
      FLEET_SERVER_ENABLE: "true"
      FLEET_SERVER_ELASTICSEARCH_HOST: "https://elasticsearch:9200"
      FLEET_SERVER_ELASTICSEARCH_USERNAME: "${ELASTIC_USERNAME}"
      FLEET_SERVER_ELASTICSEARCH_PASSWORD: "${ELASTIC_PASSWORD}"
      FLEET_SERVER_ELASTICSEARCH_CA: "/certs/ca.crt"

      # Fleet Server binding
      FLEET_SERVER_HOST: "0.0.0.0"
      FLEET_SERVER_PORT: "8220"
      FLEET_SERVER_POLICY_ID: "fleet-server-policy"

      # SSL/TLS Configuration
      FLEET_SERVER_CERT: "/certs/fleet-server.crt"
      FLEET_SERVER_CERT_KEY: "/certs/fleet-server.key"
      FLEET_SERVER_CLIENT_CA: "/certs/ca.crt"

      # Kibana configuration
      KIBANA_FLEET_SETUP: "true"
      KIBANA_FLEET_HOST: "https://kibana:5601"
      KIBANA_FLEET_USERNAME: "${ELASTIC_USERNAME}"
      KIBANA_FLEET_PASSWORD: "${ELASTIC_PASSWORD}"
      KIBANA_FLEET_CA: "/certs/ca.crt"

      # Service token (generate via Kibana)
      FLEET_SERVER_SERVICE_TOKEN: "${FLEET_SERVER_SERVICE_TOKEN}"

      # Performance tuning
      FLEET_SERVER_MAX_AGENTS: 10000
      FLEET_SERVER_MAX_CONNECTIONS: 1000

    volumes:
      - fleet-server-data:/usr/share/elastic-agent/state
      - ./secrets/certs:/certs:ro

    ports:
      - "8220:8220"

    networks:
      - elastic

    healthcheck:
      test: ["CMD-SHELL", "curl -sf https://localhost:8220/api/status --cacert /certs/ca.crt || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536

volumes:
  fleet-server-data:

networks:
  elastic:
    external: true
```

#### 2.2 Setup Fleet Server via Kibana

**Script d'initialisation:** `scripts/setup-fleet-server.sh`

```bash
#!/bin/bash
# Setup Fleet Server et génération du service token

set -euo pipefail

KIBANA_URL="https://localhost:5601"
ES_URL="https://localhost:9200"

echo "🚀 Setting up Fleet Server"

# 1. Activer Fleet dans Kibana
echo "📋 Step 1: Enable Fleet in Kibana"
curl -X POST "${KIBANA_URL}/api/fleet/setup" \
    -u elastic:${ELASTIC_PASSWORD} \
    --cacert secrets/certs/ca/ca.crt \
    -H 'kbn-xsrf: true' \
    -H 'Content-Type: application/json'

# 2. Créer Fleet Server policy
echo "📋 Step 2: Create Fleet Server policy"
POLICY_RESPONSE=$(curl -s -X POST "${KIBANA_URL}/api/fleet/agent_policies" \
    -u elastic:${ELASTIC_PASSWORD} \
    --cacert secrets/certs/ca/ca.crt \
    -H 'kbn-xsrf: true' \
    -H 'Content-Type: application/json' -d'{
        "name": "Fleet Server Policy",
        "description": "Policy for Fleet Server",
        "namespace": "default",
        "monitoring_enabled": ["logs", "metrics"],
        "has_fleet_server": true
    }')

POLICY_ID=$(echo "$POLICY_RESPONSE" | jq -r '.item.id')
echo "✅ Policy created: $POLICY_ID"

# 3. Générer service token
echo "📋 Step 3: Generate service token"
TOKEN_RESPONSE=$(curl -s -X POST "${ES_URL}/_security/service/elastic/fleet-server/credential/token/fleet-token" \
    -u elastic:${ELASTIC_PASSWORD} \
    --cacert secrets/certs/ca/ca.crt \
    -H 'Content-Type: application/json')

SERVICE_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.token.value')

# 4. Sauvegarder token dans .env
echo "📋 Step 4: Save service token"
if ! grep -q "FLEET_SERVER_SERVICE_TOKEN" .env; then
    echo "" >> .env
    echo "# Fleet Server Service Token" >> .env
    echo "FLEET_SERVER_SERVICE_TOKEN=${SERVICE_TOKEN}" >> .env
else
    sed -i "s/FLEET_SERVER_SERVICE_TOKEN=.*/FLEET_SERVER_SERVICE_TOKEN=${SERVICE_TOKEN}/" .env
fi

echo "✅ Fleet Server setup completed!"
echo ""
echo "Next steps:"
echo "1. Update FLEET_SERVER_POLICY_ID in docker-compose.fleet.yml to: $POLICY_ID"
echo "2. Start Fleet Server: docker-compose -f docker-compose.fleet.yml up -d"
echo "3. Enroll agents using Fleet UI in Kibana"
```

### 3. Elastic Agent Deployment

#### 3.1 Installation Elastic Agent sur Serveur

**Script d'installation:** `scripts/install-elastic-agent.sh`

```bash
#!/bin/bash
# Installation Elastic Agent sur serveur Linux

set -euo pipefail

# Configuration
AGENT_VERSION="8.19.10"
FLEET_URL="https://fleet-server.example.com:8220"
ENROLLMENT_TOKEN=""  # Obtenir depuis Kibana Fleet UI

# Download Elastic Agent
echo "📥 Downloading Elastic Agent ${AGENT_VERSION}"
wget -q "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-${AGENT_VERSION}-linux-x86_64.tar.gz"
tar xzf "elastic-agent-${AGENT_VERSION}-linux-x86_64.tar.gz"
cd "elastic-agent-${AGENT_VERSION}-linux-x86_64"

# Install as service
echo "📦 Installing Elastic Agent"
sudo ./elastic-agent install \
    --url="${FLEET_URL}" \
    --enrollment-token="${ENROLLMENT_TOKEN}" \
    --certificate-authorities="/path/to/ca.crt" \
    --insecure \
    --non-interactive

echo "✅ Elastic Agent installed and enrolled"
echo "📊 Check status: sudo elastic-agent status"
```

#### 3.2 Agent Policy Configuration

**Policy pour monitoring système:**

```json
{
  "name": "System Monitoring Policy",
  "description": "Collect system logs and metrics",
  "namespace": "default",
  "monitoring_enabled": ["logs", "metrics"],
  "agent_features": [],
  "package_policies": [
    {
      "name": "system-1",
      "package": {
        "name": "system",
        "version": "1.20.4"
      },
      "inputs": [
        {
          "type": "logfile",
          "enabled": true,
          "streams": [
            {
              "enabled": true,
              "data_stream": {
                "type": "logs",
                "dataset": "system.auth"
              },
              "vars": {
                "paths": {
                  "value": ["/var/log/auth.log", "/var/log/secure"]
                }
              }
            },
            {
              "enabled": true,
              "data_stream": {
                "type": "logs",
                "dataset": "system.syslog"
              },
              "vars": {
                "paths": {
                  "value": ["/var/log/syslog", "/var/log/messages"]
                }
              }
            }
          ]
        },
        {
          "type": "system/metrics",
          "enabled": true,
          "streams": [
            {
              "enabled": true,
              "data_stream": {
                "type": "metrics",
                "dataset": "system.cpu"
              },
              "vars": {
                "period": {"value": "10s"},
                "cpu.metrics": {"value": ["percentages", "normalized_percentages"]}
              }
            },
            {
              "enabled": true,
              "data_stream": {
                "type": "metrics",
                "dataset": "system.memory"
              },
              "vars": {
                "period": {"value": "10s"}
              }
            },
            {
              "enabled": true,
              "data_stream": {
                "type": "metrics",
                "dataset": "system.network"
              },
              "vars": {
                "period": {"value": "10s"}
              }
            },
            {
              "enabled": true,
              "data_stream": {
                "type": "metrics",
                "dataset": "system.filesystem"
              },
              "vars": {
                "period": {"value": "1m"}
              }
            }
          ]
        }
      ]
    }
  ]
}
```

**Policy pour Docker monitoring:**

```json
{
  "name": "Docker Monitoring Policy",
  "package_policies": [
    {
      "name": "docker-1",
      "package": {
        "name": "docker",
        "version": "1.11.0"
      },
      "inputs": [
        {
          "type": "docker/metrics",
          "enabled": true,
          "streams": [
            {
              "enabled": true,
              "data_stream": {
                "type": "metrics",
                "dataset": "docker.container"
              },
              "vars": {
                "period": {"value": "10s"},
                "hosts": {"value": ["unix:///var/run/docker.sock"]}
              }
            },
            {
              "enabled": true,
              "data_stream": {
                "type": "metrics",
                "dataset": "docker.cpu"
              }
            },
            {
              "enabled": true,
              "data_stream": {
                "type": "metrics",
                "dataset": "docker.memory"
              }
            },
            {
              "enabled": true,
              "data_stream": {
                "type": "metrics",
                "dataset": "docker.network"
              }
            }
          ]
        }
      ]
    }
  ]
}
```

### 4. Intégrations Fleet

#### 4.1 Nginx Integration

```json
{
  "name": "nginx-integration",
  "package": {
    "name": "nginx",
    "version": "1.14.0"
  },
  "inputs": [
    {
      "type": "logfile",
      "enabled": true,
      "streams": [
        {
          "enabled": true,
          "data_stream": {
            "type": "logs",
            "dataset": "nginx.access"
          },
          "vars": {
            "paths": {"value": ["/var/log/nginx/access.log*"]},
            "tags": {"value": ["nginx", "access"]},
            "processors": {
              "value": "- add_fields:\n    target: ''\n    fields:\n      environment: production"
            }
          }
        },
        {
          "enabled": true,
          "data_stream": {
            "type": "logs",
            "dataset": "nginx.error"
          },
          "vars": {
            "paths": {"value": ["/var/log/nginx/error.log*"]},
            "tags": {"value": ["nginx", "error"]}
          }
        }
      ]
    },
    {
      "type": "nginx/metrics",
      "enabled": true,
      "streams": [
        {
          "enabled": true,
          "data_stream": {
            "type": "metrics",
            "dataset": "nginx.stubstatus"
          },
          "vars": {
            "period": {"value": "10s"},
            "server_status_path": {"value": "/nginx_status"},
            "hosts": {"value": ["http://127.0.0.1:80"]}
          }
        }
      ]
    }
  ]
}
```

#### 4.2 Custom Logs Integration (FreqTrade)

```json
{
  "name": "freqtrade-logs",
  "package": {
    "name": "custom_logs",
    "version": "1.0.0"
  },
  "inputs": [
    {
      "type": "logfile",
      "enabled": true,
      "streams": [
        {
          "enabled": true,
          "data_stream": {
            "type": "logs",
            "dataset": "freqtrade.bot"
          },
          "vars": {
            "paths": {"value": ["/home/freqtrade/logs/*.log"]},
            "tags": {"value": ["freqtrade", "trading", "bot1"]},
            "multiline": {
              "value": {
                "pattern": "^[0-9]{4}-[0-9]{2}-[0-9]{2}",
                "negate": true,
                "match": "after"
              }
            },
            "processors": {
              "value": "- add_fields:\n    target: ''\n    fields:\n      bot.id: bot1\n      bot.strategy: NFI5MOHO\n      environment: production\n- dissect:\n    tokenizer: '%{timestamp} - %{logger} - %{level} - %{message}'\n    field: message\n    target_prefix: ''"
            }
          }
        }
      ]
    }
  ]
}
```

### 5. Fleet Server Haute Disponibilité

**Configuration multi-instances:**

```yaml
services:
  fleet-server-1:
    <<: *fleet-server-template
    container_name: fleet-server-1
    hostname: fleet-server-1
    environment:
      FLEET_SERVER_FLEET_SERVER_HOST: "fleet-server-1"

  fleet-server-2:
    <<: *fleet-server-template
    container_name: fleet-server-2
    hostname: fleet-server-2
    environment:
      FLEET_SERVER_FLEET_SERVER_HOST: "fleet-server-2"

  fleet-server-3:
    <<: *fleet-server-template
    container_name: fleet-server-3
    hostname: fleet-server-3
    environment:
      FLEET_SERVER_FLEET_SERVER_HOST: "fleet-server-3"

  # Load balancer pour Fleet Server
  fleet-lb:
    image: nginx:alpine
    container_name: fleet-lb
    volumes:
      - ./fleet-nginx.conf:/etc/nginx/nginx.conf:ro
    ports:
      - "8220:8220"
    depends_on:
      - fleet-server-1
      - fleet-server-2
      - fleet-server-3
    networks:
      - elastic
```

**fleet-nginx.conf:**

```nginx
upstream fleet_servers {
    least_conn;
    server fleet-server-1:8220 max_fails=3 fail_timeout=30s;
    server fleet-server-2:8220 max_fails=3 fail_timeout=30s;
    server fleet-server-3:8220 max_fails=3 fail_timeout=30s;
}

server {
    listen 8220 ssl http2;

    ssl_certificate /certs/fleet-lb.crt;
    ssl_certificate_key /certs/fleet-lb.key;
    ssl_client_certificate /certs/ca.crt;
    ssl_verify_client optional;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass https://fleet_servers;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /api/status {
        access_log off;
        proxy_pass https://fleet_servers;
    }
}
```

---

## 📝 Audit Logging

### Configuration Audit Logging

**elasticsearch.yml:**

```yaml
#========================= Audit Logging =================================

# Enable audit logging (Gold/Platinum license required)
xpack.security.audit.enabled: true

# Audit event types to log
xpack.security.audit.logfile.events.include:
  - access_denied
  - access_granted
  - anonymous_access_denied
  - authentication_failed
  - authentication_success
  - connection_denied
  - connection_granted
  - tampered_request
  - run_as_denied
  - run_as_granted
  - security_config_change

# Events to exclude (too verbose)
xpack.security.audit.logfile.events.exclude:
  - authentication_success  # En production, garder uniquement échecs

# Ignore system users
xpack.security.audit.logfile.events.ignore_filters:
  monitor_health:
    users: ["kibana_system", "logstash_system"]
    actions: ["cluster:monitor/health"]

# Output destination
xpack.security.audit.outputs: [logfile, index]

# Logfile output
xpack.security.audit.logfile.prefix: "audit"
xpack.security.audit.logfile.suffix: ".log"

# Index output (index dans Elasticsearch)
xpack.security.audit.index.bulk_size: 5000
xpack.security.audit.index.flush_interval: 1s
xpack.security.audit.index.rollover: daily
xpack.security.audit.index.settings:
  index:
    number_of_shards: 1
    number_of_replicas: 1
```

### Analyse des Logs d'Audit

**Dashboard Kibana pour audit logs:**

```bash
# Requête: Échecs d'authentification récents
GET .security-audit-*/_search
{
  "query": {
    "bool": {
      "must": [
        { "term": { "event.action": "authentication_failed" }},
        { "range": { "@timestamp": { "gte": "now-1h" }}}
      ]
    }
  },
  "aggs": {
    "failed_users": {
      "terms": { "field": "user.name", "size": 10 }
    },
    "failed_ips": {
      "terms": { "field": "source.ip", "size": 10 }
    }
  }
}

# Requête: Modifications de configuration sécurité
GET .security-audit-*/_search
{
  "query": {
    "term": { "event.action": "security_config_change" }
  },
  "sort": [{ "@timestamp": "desc" }],
  "size": 100
}

# Requête: Accès refusés par utilisateur
GET .security-audit-*/_search
{
  "query": {
    "bool": {
      "must": [
        { "term": { "event.action": "access_denied" }},
        { "term": { "user.name": "suspicious_user" }}
      ]
    }
  }
}
```

---

## 🎯 Résumé & Checklist de Déploiement

### Checklist Sécurité Complète

- [ ] ✅ Certificats SSL/TLS production générés (CA + services)
- [ ] ✅ TLS 1.3 activé avec ciphersuites modernes
- [ ] ✅ RBAC configuré avec rôles custom
- [ ] ✅ Utilisateurs créés par équipe (DevOps, Dev, Security)
- [ ] ✅ API Keys configurées avec rotation automatique
- [ ] ✅ Document/Field Level Security activé si nécessaire
- [ ] ✅ Audit logging activé et dashboard créé
- [ ] ✅ IP whitelisting configuré (Nginx/ES)
- [ ] ✅ Rate limiting activé (Nginx)

### Checklist APM

- [ ] ✅ APM Server déployé avec SSL/TLS
- [ ] ✅ API Key authentication configurée
- [ ] ✅ Sampling configuré (tail-based)
- [ ] ✅ Applications instrumentées (Node.js/Python)
- [ ] ✅ RUM activé pour frontend (si applicable)
- [ ] ✅ Service maps visibles dans Kibana
- [ ] ✅ Alerting configuré (error rate, latency)
- [ ] ✅ ILM configuré pour traces/metrics

### Checklist Fleet

- [ ] ✅ Fleet Server déployé avec SSL
- [ ] ✅ Service token généré et sécurisé
- [ ] ✅ Policies créées (System, Docker, Custom)
- [ ] ✅ Agents enrollés sur serveurs
- [ ] ✅ Intégrations configurées (Nginx, etc.)
- [ ] ✅ Haute disponibilité Fleet (3+ instances)
- [ ] ✅ Monitoring Fleet Server actif

### Scripts Disponibles

| Script | Fonction | Cron |
|--------|----------|------|
| `generate-production-certs.sh` | Génération certificats SSL | Manual |
| `rotate-certificates.sh` | Rotation auto certificats | Weekly |
| `create-users.sh` | Création utilisateurs RBAC | Manual |
| `rotate-api-keys.sh` | Rotation auto API keys | Daily |
| `setup-fleet-server.sh` | Setup Fleet Server initial | Manual |
| `install-elastic-agent.sh` | Installation agent sur serveur | Per server |

---

**Document créé:** 2025-01-27
**Version Elastic Stack:** 8.19.10 / 9.2.4
**Auteur:** Claude (Anthropic)
**Prochaine révision:** Après migration version majeure

---

## 📚 Ressources Officielles

- [Security Best Practices](https://www.elastic.co/guide/en/elasticsearch/reference/current/security-minimal-setup.html)
- [APM Guide](https://www.elastic.co/guide/en/apm/guide/current/index.html)
- [Fleet & Elastic Agent](https://www.elastic.co/guide/en/fleet/current/index.html)
- [RBAC Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/authorization.html)
- [API Keys](https://www.elastic.co/guide/en/elasticsearch/reference/current/security-api-create-api-key.html)
- [Audit Logging](https://www.elastic.co/guide/en/elasticsearch/reference/current/enable-audit-logging.html)
