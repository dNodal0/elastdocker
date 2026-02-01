#!/bin/bash
###################### Elastic Agent - Create Fleet Integrations ######################
# Purpose: Créer les 3 intégrations Fleet (fail2ban, Asterisk, auth) liées aux pipelines
# Prérequis: ./create-ingest-pipelines.sh exécuté avant
# Usage: ELASTIC_PASSWORD='xxx' ./create-fleet-integrations.sh

set -e

# Configuration
KIBANA="${KIBANA_HOST:-https://kibana.elastic.local}"
ES_USER="${ELASTIC_USERNAME:-elastic}"
ES_PASS="${ELASTIC_PASSWORD}"
AGENT_POLICY_ID="${AGENT_POLICY_ID:-e7398cde-2b00-4443-9555-53be3fc4448b}"
PKG_NAME="filestream"
PKG_VERSION="2.3.1"

if [ -z "$ES_PASS" ]; then
    echo "❌ ELASTIC_PASSWORD non défini"
    exit 1
fi

echo "🔧 Création Intégrations Fleet pour Elastic Agent"
echo "   Kibana: $KIBANA"
echo "   Policy: $AGENT_POLICY_ID"
echo "   Package: ${PKG_NAME} v${PKG_VERSION}"
echo ""

# Test connexion Kibana
echo "🔍 Test connexion Kibana..."
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" \
  -u "$ES_USER:$ES_PASS" \
  -H "kbn-xsrf: true" \
  "${KIBANA}/api/fleet/agent_policies/${AGENT_POLICY_ID}")

if [ "$HTTP_CODE" != "200" ]; then
    echo "❌ Connexion échouée ou policy introuvable (HTTP $HTTP_CODE)"
    exit 1
fi
echo "✅ Connexion OK"
echo ""

#========================= INTEGRATION ASTERISK ========================================

echo "📋 Création intégration: Asterisk-Security-Logs..."

PAYLOAD_ASTERISK=$(cat <<'ENDJSON'
{
  "name": "Asterisk-Security-Logs",
  "description": "Asterisk security logs avec pipeline logs-asterisk-security",
  "namespace": "security",
  "policy_id": "POLICY_ID_PLACEHOLDER",
  "package": { "name": "filestream", "version": "2.3.1" },
  "inputs": [
    {
      "type": "filestream",
      "policy_template": "filestream",
      "enabled": true,
      "streams": [
        {
          "enabled": true,
          "data_stream": {
            "type": "logs",
            "dataset": "filestream.filestream",
            "elasticsearch": {
              "dynamic_dataset": true,
              "dynamic_namespace": true
            }
          },
          "vars": {
            "paths": {
              "type": "text",
              "value": [
                "/var/log/asterisk/security",
                "/var/log/asterisk/messages",
                "/var/log/asterisk/full"
              ]
            },
            "data_stream.dataset": {
              "type": "text",
              "value": "asterisk"
            },
            "pipeline": {
              "type": "text",
              "value": "logs-asterisk-security"
            },
            "parsers": {
              "type": "yaml",
              "value": "- multiline:\n    type: pattern\n    pattern: '^\\['\n    negate: true\n    match: after\n"
            },
            "exclude_lines": {
              "type": "text",
              "value": ["^\\[.*\\] DEBUG", "^\\[.*\\] VERBOSE"]
            },
            "exclude_files": {
              "type": "text",
              "value": ["\\.gz$"]
            },
            "include_files": {
              "type": "text",
              "value": []
            },
            "processors": {
              "type": "yaml",
              "value": "- add_fields:\n    target: ''\n    fields:\n      log_type: asterisk\n"
            },
            "tags": {
              "type": "text",
              "value": ["security asterisk production"]
            },
            "compression_gzip": {
              "type": "bool",
              "value": true
            },
            "use_logs_stream": {
              "type": "bool",
              "value": true
            },
            "recursive_glob": {
              "type": "bool",
              "value": true
            },
            "fingerprint": {
              "type": "bool",
              "value": true
            },
            "fingerprint_offset": {
              "type": "integer",
              "value": 0
            },
            "fingerprint_length": {
              "type": "integer",
              "value": 1024
            },
            "file_identity_native": {
              "type": "bool",
              "value": false
            },
            "harvester_limit": {
              "type": "integer",
              "value": 0
            },
            "clean_inactive": {
              "type": "text",
              "value": -1
            },
            "delete_enabled": {
              "type": "bool",
              "value": false
            },
            "include_lines": {
              "type": "text",
              "value": []
            }
          }
        }
      ]
    }
  ]
}
ENDJSON
)

PAYLOAD_ASTERISK=$(echo "$PAYLOAD_ASTERISK" | sed "s/POLICY_ID_PLACEHOLDER/${AGENT_POLICY_ID}/g")

RESPONSE=$(curl -k -s -w "\n%{http_code}" \
  -u "$ES_USER:$ES_PASS" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -X POST "${KIBANA}/api/fleet/package_policies" \
  -d "$PAYLOAD_ASTERISK")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    ID=$(echo "$BODY" | jq -r '.item.id // "unknown"')
    echo "  ✅ Créé (ID: ${ID})"
elif echo "$BODY" | jq -r '.message // empty' 2>/dev/null | grep -qi "already exists"; then
    echo "  ⚠️  Existe déjà, skip"
else
    echo "  ❌ Erreur HTTP ${HTTP_CODE}:"
    echo "$BODY" | jq -r '.message // .' 2>/dev/null || echo "$BODY"
fi
echo ""

#========================= INTEGRATION AUTH/SSH ========================================

echo "📋 Création intégration: Auth-SSH-Security-Logs..."

PAYLOAD_AUTH=$(cat <<'ENDJSON'
{
  "name": "Auth-SSH-Security-Logs",
  "description": "SSH et auth logs avec pipeline logs-auth-security",
  "namespace": "security",
  "policy_id": "POLICY_ID_PLACEHOLDER",
  "package": { "name": "filestream", "version": "2.3.1" },
  "inputs": [
    {
      "type": "filestream",
      "policy_template": "filestream",
      "enabled": true,
      "streams": [
        {
          "enabled": true,
          "data_stream": {
            "type": "logs",
            "dataset": "filestream.filestream",
            "elasticsearch": {
              "dynamic_dataset": true,
              "dynamic_namespace": true
            }
          },
          "vars": {
            "paths": {
              "type": "text",
              "value": [
                "/var/log/auth.log",
                "/var/log/secure"
              ]
            },
            "data_stream.dataset": {
              "type": "text",
              "value": "auth"
            },
            "pipeline": {
              "type": "text",
              "value": "logs-auth-security"
            },
            "parsers": {
              "type": "yaml",
              "value": ""
            },
            "exclude_lines": {
              "type": "text",
              "value": []
            },
            "exclude_files": {
              "type": "text",
              "value": ["\\.gz$"]
            },
            "include_files": {
              "type": "text",
              "value": []
            },
            "processors": {
              "type": "yaml",
              "value": "- add_fields:\n    target: ''\n    fields:\n      log_type: auth\n"
            },
            "tags": {
              "type": "text",
              "value": ["security auth ssh production"]
            },
            "compression_gzip": {
              "type": "bool",
              "value": true
            },
            "use_logs_stream": {
              "type": "bool",
              "value": true
            },
            "recursive_glob": {
              "type": "bool",
              "value": true
            },
            "fingerprint": {
              "type": "bool",
              "value": true
            },
            "fingerprint_offset": {
              "type": "integer",
              "value": 0
            },
            "fingerprint_length": {
              "type": "integer",
              "value": 1024
            },
            "file_identity_native": {
              "type": "bool",
              "value": false
            },
            "harvester_limit": {
              "type": "integer",
              "value": 0
            },
            "clean_inactive": {
              "type": "text",
              "value": -1
            },
            "delete_enabled": {
              "type": "bool",
              "value": false
            },
            "include_lines": {
              "type": "text",
              "value": []
            }
          }
        }
      ]
    }
  ]
}
ENDJSON
)

PAYLOAD_AUTH=$(echo "$PAYLOAD_AUTH" | sed "s/POLICY_ID_PLACEHOLDER/${AGENT_POLICY_ID}/g")

RESPONSE=$(curl -k -s -w "\n%{http_code}" \
  -u "$ES_USER:$ES_PASS" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -X POST "${KIBANA}/api/fleet/package_policies" \
  -d "$PAYLOAD_AUTH")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    ID=$(echo "$BODY" | jq -r '.item.id // "unknown"')
    echo "  ✅ Créé (ID: ${ID})"
elif echo "$BODY" | jq -r '.message // empty' 2>/dev/null | grep -qi "already exists"; then
    echo "  ⚠️  Existe déjà, skip"
else
    echo "  ❌ Erreur HTTP ${HTTP_CODE}:"
    echo "$BODY" | jq -r '.message // .' 2>/dev/null || echo "$BODY"
fi
echo ""

#========================= VERIFICATION ========================================

echo "🔍 Vérification intégrations sur la policy..."
echo ""

curl -k -s -u "$ES_USER:$ES_PASS" \
  -H "kbn-xsrf: true" \
  "${KIBANA}/api/fleet/package_policies?perPage=100" | \
  jq -r '.items[] | select(.policy_id == "'"${AGENT_POLICY_ID}"'") | "  ✅ \(.name) → dataset: \(.inputs[0].streams[0].vars["data_stream.dataset"].value // "default")"' 2>/dev/null

echo ""
echo "✅ Terminé!"
echo ""
echo "📋 Prochaines étapes:"
echo "  1. Vérifier dans Kibana → Fleet → Agent Policies"
echo "  2. sudo systemctl restart elastic-agent (sur les NUCs)"
echo "  3. Discover → logs-*-security* → attacker_ip:* AND event.type:*"
echo ""
