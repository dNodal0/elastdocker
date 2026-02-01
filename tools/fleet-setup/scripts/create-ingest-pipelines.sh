#!/bin/bash
###################### Elastic Agent - Create Ingest Pipelines ######################
# Purpose: Créer les 3 pipelines de parsing pour fail2ban, Asterisk, auth logs
# Usage: ./create-ingest-pipelines.sh

set -e

# Configuration
ES_HOST="${ELASTICSEARCH_HOST:-https://192.168.2.102:9200}"
ES_USER="${ELASTIC_USERNAME:-elastic}"
ES_PASS="${ELASTIC_PASSWORD}"

if [ -z "$ES_PASS" ]; then
    echo "❌ ELASTIC_PASSWORD non défini"
    exit 1
fi

echo "🔧 Création Ingest Pipelines pour Elastic Agent"
echo "   Host: $ES_HOST"
echo ""

# Test connexion
echo "🔍 Test connexion Elasticsearch..."
curl -k -s -u "$ES_USER:$ES_PASS" "$ES_HOST/_cluster/health" > /dev/null || {
    echo "❌ Impossible de se connecter à Elasticsearch"
    exit 1
}
echo "✅ Connexion OK"
echo ""

#========================= PIPELINE FAIL2BAN ========================================

echo "📋 Création Pipeline Fail2ban..."
curl -k -X PUT "$ES_HOST/_ingest/pipeline/logs-fail2ban-security" \
  -u "$ES_USER:$ES_PASS" \
  -H 'Content-Type: application/json' \
  -d '{
  "description": "Parse fail2ban logs with GeoIP enrichment",
  "processors": [
    {
      "grok": {
        "field": "message",
        "patterns": [
          "%{TIMESTAMP_ISO8601:timestamp}%{SPACE}%{DATA:fail2ban_logger}%{SPACE}\\[%{NUMBER:pid}\\]:%{SPACE}%{WORD:log_level}%{SPACE}\\[%{DATA:jail}\\]%{SPACE}%{WORD:action}%{SPACE}%{IP:attacker_ip}",
          "%{TIMESTAMP_ISO8601:timestamp}%{SPACE}%{DATA:fail2ban_logger}%{SPACE}\\[%{NUMBER:pid}\\]:%{SPACE}%{WORD:log_level}%{SPACE}\\[%{DATA:jail}\\]%{SPACE}Unban%{SPACE}%{IP:attacker_ip}",
          "%{TIMESTAMP_ISO8601:timestamp}%{SPACE}%{DATA:fail2ban_logger}%{SPACE}\\[%{NUMBER:pid}\\]:%{SPACE}%{WORD:log_level}%{SPACE}\\[%{DATA:jail}\\]%{SPACE}Found%{SPACE}%{IP:attacker_ip}"
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
        "if": "ctx.action == '\''ban'\''",
        "field": "event.type",
        "value": "banned"
      }
    },
    {
      "set": {
        "if": "ctx.action == '\''ban'\''",
        "field": "event.category",
        "value": "security"
      }
    },
    {
      "set": {
        "if": "ctx.action == '\''ban'\''",
        "field": "event.severity",
        "value": "high"
      }
    },
    {
      "set": {
        "if": "ctx.action == '\''unban'\''",
        "field": "event.type",
        "value": "unbanned"
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
        "target_field": "@timestamp",
        "ignore_failure": true
      }
    },
    {
      "remove": {
        "field": ["timestamp"],
        "ignore_missing": true
      }
    }
  ]
}'
echo -e "\n✅ Pipeline Fail2ban créé"
echo ""

#========================= PIPELINE ASTERISK ========================================

echo "📋 Création Pipeline Asterisk..."
curl -k -X PUT "$ES_HOST/_ingest/pipeline/logs-asterisk-security" \
  -u "$ES_USER:$ES_PASS" \
  -H 'Content-Type: application/json' \
  -d '{
  "description": "Parse Asterisk security logs with GeoIP",
  "processors": [
    {
      "grok": {
        "field": "message",
        "patterns": [
          "\\[%{TIMESTAMP_ISO8601:timestamp}\\]%{SPACE}SECURITY\\[%{NUMBER:thread_id}\\]%{SPACE}%{DATA:source_file}:%{SPACE}Registration from '\''%{DATA:sip_uri}'\'' failed for '\''%{IP:attacker_ip}:%{NUMBER:port}'\'' - %{GREEDYDATA:failure_reason}",
          "\\[%{TIMESTAMP_ISO8601:timestamp}\\]%{SPACE}NOTICE\\[%{NUMBER:thread_id}\\]%{SPACE}%{DATA:source_file}:%{SPACE}Registration from '\''%{DATA:sip_uri}'\'' failed for '\''%{IP:attacker_ip}:%{NUMBER:port}'\'' - %{GREEDYDATA:failure_reason}",
          "\\[%{TIMESTAMP_ISO8601:timestamp}\\]%{SPACE}WARNING\\[%{NUMBER:thread_id}\\]%{SPACE}%{DATA:source_file}:%{SPACE}Failed to authenticate device %{QUOTEDSTRING:device_info}",
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
        "strip_brackets": true,
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
        "if": "ctx.security_event != null || ctx.failure_reason != null",
        "field": "event.category",
        "value": "security"
      }
    },
    {
      "script": {
        "if": "ctx.security_event != null",
        "lang": "painless",
        "source": "if (ctx.security_event =~ /InvalidPassword|FailedACL|InvalidAccountID/) { ctx['\''event'\'']['\''severity'\''] = '\''high'\''; } else { ctx['\''event'\'']['\''severity'\''] = '\''medium'\''; }",
        "ignore_failure": true
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
        "target_field": "@timestamp",
        "ignore_failure": true
      }
    },
    {
      "remove": {
        "field": ["timestamp"],
        "ignore_missing": true
      }
    }
  ]
}'
echo -e "\n✅ Pipeline Asterisk créé"
echo ""

#========================= PIPELINE AUTH/SSH ========================================

echo "📋 Création Pipeline Auth/SSH..."
curl -k -X PUT "$ES_HOST/_ingest/pipeline/logs-auth-security" \
  -u "$ES_USER:$ES_PASS" \
  -H 'Content-Type: application/json' \
  -d '{
  "description": "Parse SSH/Auth logs with GeoIP",
  "processors": [
    {
      "grok": {
        "field": "message",
        "patterns": [
          "%{SYSLOGTIMESTAMP:timestamp}%{SPACE}%{HOSTNAME:hostname}%{SPACE}sshd\\[%{NUMBER:pid}\\]:%{SPACE}Failed password for %{USER:username} from %{IP:attacker_ip} port %{NUMBER:port} ssh2",
          "%{SYSLOGTIMESTAMP:timestamp}%{SPACE}%{HOSTNAME:hostname}%{SPACE}sshd\\[%{NUMBER:pid}\\]:%{SPACE}Invalid user %{USER:username} from %{IP:attacker_ip} port %{NUMBER:port}",
          "%{SYSLOGTIMESTAMP:timestamp}%{SPACE}%{HOSTNAME:hostname}%{SPACE}sshd\\[%{NUMBER:pid}\\]:%{SPACE}Accepted %{WORD:auth_method} for %{USER:username} from %{IP:source_ip} port %{NUMBER:port} ssh2",
          "%{SYSLOGTIMESTAMP:timestamp}%{SPACE}%{HOSTNAME:hostname}%{SPACE}sudo:%{SPACE}%{USER:username}%{SPACE}:%{SPACE}TTY=%{DATA:tty}%{SPACE};%{SPACE}PWD=%{DATA:pwd}%{SPACE};%{SPACE}USER=%{USER:target_user}%{SPACE};%{SPACE}COMMAND=%{GREEDYDATA:command}"
        ],
        "ignore_failure": true
      }
    },
    {
      "set": {
        "if": "ctx.message?.contains('\''Failed password'\'') || ctx.message?.contains('\''Invalid user'\'')",
        "field": "event.type",
        "value": "ssh_failed_auth"
      }
    },
    {
      "set": {
        "if": "ctx.message?.contains('\''Failed password'\'') || ctx.message?.contains('\''Invalid user'\'')",
        "field": "event.category",
        "value": "security"
      }
    },
    {
      "set": {
        "if": "ctx.message?.contains('\''Failed password'\'') || ctx.message?.contains('\''Invalid user'\'')",
        "field": "event.severity",
        "value": "high"
      }
    },
    {
      "set": {
        "if": "ctx.message?.contains('\''Accepted'\'')",
        "field": "event.type",
        "value": "ssh_successful_auth"
      }
    },
    {
      "set": {
        "if": "ctx.message?.contains('\''Accepted'\'')",
        "field": "event.category",
        "value": "audit"
      }
    },
    {
      "set": {
        "if": "ctx.command != null",
        "field": "event.type",
        "value": "privilege_escalation"
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
        "target_field": "@timestamp",
        "timezone": "Europe/Paris",
        "ignore_failure": true
      }
    }
  ]
}'
echo -e "\n✅ Pipeline Auth/SSH créé"
echo ""

#========================= VERIFICATION ========================================

echo "🔍 Vérification pipelines créés..."
echo ""

PIPELINES=$(curl -k -s -u "$ES_USER:$ES_PASS" "$ES_HOST/_ingest/pipeline/logs-*-security" | jq -r 'keys[]')

echo "  Pipelines créés:"
echo "$PIPELINES" | while read pipeline; do
    echo "    ✅ $pipeline"
done

echo ""

#========================= TEST PIPELINE ========================================

echo "🧪 Test Pipeline Fail2ban..."

TEST_RESULT=$(curl -k -s -X POST "$ES_HOST/_ingest/pipeline/logs-fail2ban-security/_simulate" \
  -u "$ES_USER:$ES_PASS" \
  -H 'Content-Type: application/json' \
  -d '{
  "docs": [
    {
      "_source": {
        "message": "2025-01-31 10:15:23,456 fail2ban.actions [12345]: NOTICE [sshd] Ban 185.220.101.45"
      }
    }
  ]
}')

# Vérifier si parsing OK
ATTACKER_IP=$(echo "$TEST_RESULT" | jq -r '.docs[0].doc._source.attacker_ip' 2>/dev/null)
EVENT_TYPE=$(echo "$TEST_RESULT" | jq -r '.docs[0].doc._source.event.type' 2>/dev/null)
GEOIP_COUNTRY=$(echo "$TEST_RESULT" | jq -r '.docs[0].doc._source.geoip.country_name' 2>/dev/null)

if [ "$ATTACKER_IP" = "185.220.101.45" ] && [ "$EVENT_TYPE" = "banned" ]; then
    echo "  ✅ Parsing OK"
    echo "     - IP extraite: $ATTACKER_IP"
    echo "     - Event type: $EVENT_TYPE"
    [ "$GEOIP_COUNTRY" != "null" ] && echo "     - GeoIP: $GEOIP_COUNTRY"
else
    echo "  ⚠️  Parsing incomplet"
    echo "$TEST_RESULT" | jq '.'
fi

echo ""

#========================= INSTRUCTIONS ========================================

echo "✅ Pipelines créés avec succès!"
echo ""
echo "📋 Prochaines étapes:"
echo ""
echo "1. Dans Fleet, associer les pipelines aux integrations:"
echo ""
echo "   Fail2ban Integration:"
echo "     Settings → Advanced → Custom configurations"
echo "     Pipeline: logs-fail2ban-security"
echo ""
echo "   Asterisk Integration:"
echo "     Settings → Advanced → Custom configurations"
echo "     Pipeline: logs-asterisk-security"
echo ""
echo "   System Integration (auth logs):"
echo "     Settings → Advanced → Custom configurations"
echo "     Pipeline: logs-auth-security"
echo ""
echo "2. Redémarrer Elastic Agent sur les NUCs:"
echo "   sudo systemctl restart elastic-agent"
echo ""
echo "3. Vérifier logs parsés dans Kibana Discover:"
echo "   Index pattern: logs-*-security*"
echo "   Query: attacker_ip:* AND event.type:*"
echo ""
echo "4. Créer dashboards:"
echo "   ./setup-kibana-dashboards-elastic-agent.sh"
echo ""
