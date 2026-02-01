#!/usr/bin/env bash
set -euo pipefail

KIBANA="https://kibana.elastic.local"
AUTH='elastic:t9U6nXEme6nJ0IbM1bG2D2uq2ToWnx5Hh3EQSaZxUrU='
POLICY_ID="fleet-server-policy"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

api_post() { curl -sk -u "$AUTH" -H "kbn-xsrf: true" -H "Content-Type: application/json" -XPOST "$1" -d @"$2" 2>/dev/null; }

check() {
  local resp="$1" label="$2"
  if echo "$resp" | jq -e '.item.id' &>/dev/null; then
    echo "  ✅ ${label} (ID: $(echo "$resp" | jq -r '.item.id'))"
  else
    echo "  ❌ ${label}: $(echo "$resp" | jq -r '.message // .' 2>/dev/null)"
  fi
}

exists() {
  curl -sk -u "$AUTH" -H "kbn-xsrf: true" "${KIBANA}/api/fleet/package_policies?perPage=1000" \
    | jq -r --arg pid "$POLICY_ID" --arg n "$1" '.items[] | select(.policy_id==$pid and .name==$n) | .id // empty'
}

###############################################################################
echo "━━━ Elasticsearch Integration ━━━"
###############################################################################
E=$(exists "ELK-Elasticsearch-Logs-Metrics")
if [[ -n "$E" ]]; then
  echo "  ✅ Existe déjà (ID: $E)"
else
  cat > "$TMPDIR/es.json" << 'EOF'
{
  "name": "ELK-Elasticsearch-Logs-Metrics",
  "description": "Elasticsearch server logs and stack monitoring metrics",
  "namespace": "default",
  "policy_id": "fleet-server-policy",
  "package": { "name": "elasticsearch", "title": "Elasticsearch", "version": "1.19.1" },
  "inputs": [
    {
      "type": "logfile",
      "enabled": true,
      "streams": [
        { "enabled": true, "data_stream": { "type": "logs", "dataset": "elasticsearch.server" },
          "vars": { "paths": { "value": ["/var/log/elasticsearch/*.log", "/var/log/elasticsearch/*_server.json"], "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "logs", "dataset": "elasticsearch.audit" },
          "vars": { "paths": { "value": ["/var/log/elasticsearch/*_audit.json"], "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "logs", "dataset": "elasticsearch.deprecation" },
          "vars": { "paths": { "value": ["/var/log/elasticsearch/*_deprecation.json", "/var/log/elasticsearch/*_deprecation.log"], "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "logs", "dataset": "elasticsearch.gc" },
          "vars": { "paths": { "value": ["/var/log/elasticsearch/gc.log*"], "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "logs", "dataset": "elasticsearch.slowlog" },
          "vars": { "paths": { "value": ["/var/log/elasticsearch/*_index_search_slowlog.json", "/var/log/elasticsearch/*_index_indexing_slowlog.json"], "type": "text" } } }
      ]
    },
    {
      "type": "elasticsearch/metrics",
      "enabled": true,
      "vars": {
        "hosts": { "value": ["https://localhost:9200"], "type": "text" },
        "username": { "value": "elastic", "type": "text" },
        "password": { "value": "", "type": "password" },
        "ssl.verification_mode": { "value": "none", "type": "text" },
        "scope": { "value": "node", "type": "text" }
      },
      "streams": [
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "elasticsearch.stack_monitoring.cluster_stats" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "elasticsearch.stack_monitoring.node_stats" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "elasticsearch.stack_monitoring.node" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "elasticsearch.stack_monitoring.index" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "elasticsearch.stack_monitoring.index_summary" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "elasticsearch.stack_monitoring.shard" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "elasticsearch.stack_monitoring.pending_tasks" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "elasticsearch.stack_monitoring.ccr" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "elasticsearch.stack_monitoring.enrich" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "elasticsearch.stack_monitoring.ml_job" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "elasticsearch.stack_monitoring.index_recovery" }, "vars": { "period": { "value": "10s", "type": "text" }, "active.only": { "value": true, "type": "bool" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "elasticsearch.ingest_pipeline" }, "vars": { "ingest_pipeline_processor_sampling_rate": { "value": 1, "type": "integer" } } }
      ]
    }
  ]
}
EOF
  RESP=$(api_post "${KIBANA}/api/fleet/package_policies" "$TMPDIR/es.json")
  check "$RESP" "Elasticsearch Logs+Metrics"
fi

###############################################################################
echo ""
echo "━━━ Kibana Integration ━━━"
###############################################################################
E=$(exists "ELK-Kibana-Logs-Metrics")
if [[ -n "$E" ]]; then
  echo "  ✅ Existe déjà (ID: $E)"
else
  cat > "$TMPDIR/kb.json" << 'EOF'
{
  "name": "ELK-Kibana-Logs-Metrics",
  "description": "Kibana logs and stack monitoring metrics",
  "namespace": "default",
  "policy_id": "fleet-server-policy",
  "package": { "name": "kibana", "title": "Kibana", "version": "2.8.0" },
  "inputs": [
    {
      "type": "logfile",
      "enabled": true,
      "streams": [
        { "enabled": true, "data_stream": { "type": "logs", "dataset": "kibana.log" },
          "vars": { "paths": { "value": ["/var/log/kibana/*.log"], "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "logs", "dataset": "kibana.audit" },
          "vars": { "paths": { "value": ["/var/log/kibana/*audit*.log"], "type": "text" } } }
      ]
    },
    {
      "type": "kibana/metrics",
      "enabled": true,
      "vars": {
        "hosts": { "value": ["https://localhost:5601"], "type": "text" },
        "username": { "value": "elastic", "type": "text" },
        "password": { "value": "", "type": "password" },
        "ssl.verification_mode": { "value": "none", "type": "text" },
        "condition": { "value": "", "type": "text" }
      },
      "streams": [
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "kibana.stack_monitoring.stats" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "kibana.stack_monitoring.cluster_actions" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "kibana.stack_monitoring.cluster_rules" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "kibana.stack_monitoring.node_actions" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "kibana.stack_monitoring.node_rules" }, "vars": { "period": { "value": "10s", "type": "text" } } }
      ]
    },
    { "type": "http/metrics", "enabled": false, "streams": [] }
  ]
}
EOF
  RESP=$(api_post "${KIBANA}/api/fleet/package_policies" "$TMPDIR/kb.json")
  check "$RESP" "Kibana Logs+Metrics"
fi

###############################################################################
echo ""
echo "━━━ Logstash Integration ━━━"
###############################################################################
E=$(exists "ELK-Logstash-Logs-Metrics")
if [[ -n "$E" ]]; then
  echo "  ✅ Existe déjà (ID: $E)"
else
  cat > "$TMPDIR/ls.json" << 'EOF'
{
  "name": "ELK-Logstash-Logs-Metrics",
  "description": "Logstash logs and stack monitoring metrics",
  "namespace": "default",
  "policy_id": "fleet-server-policy",
  "package": { "name": "logstash", "title": "Logstash", "version": "2.8.0" },
  "inputs": [
    {
      "type": "logfile",
      "enabled": true,
      "streams": [
        { "enabled": true, "data_stream": { "type": "logs", "dataset": "logstash.log" },
          "vars": { "paths": { "value": ["/var/log/logstash/logstash-plain*.log", "/var/log/logstash/*server*.log"], "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "logs", "dataset": "logstash.slowlog" },
          "vars": { "paths": { "value": ["/var/log/logstash/logstash-slowlog-plain*.log", "/var/log/logstash/*slowlog*.log"], "type": "text" } } }
      ]
    },
    {
      "type": "logstash/metrics",
      "enabled": true,
      "vars": {
        "hosts": { "value": ["https://localhost:9600"], "type": "text" },
        "username": { "value": "", "type": "text" },
        "password": { "value": "", "type": "password" },
        "ssl.verification_mode": { "value": "none", "type": "text" }
      },
      "streams": [
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "logstash.stack_monitoring.node_stats" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "logstash.stack_monitoring.node" }, "vars": { "period": { "value": "10s", "type": "text" } } }
      ]
    },
    { "type": "cel", "enabled": false, "streams": [] }
  ]
}
EOF
  RESP=$(api_post "${KIBANA}/api/fleet/package_policies" "$TMPDIR/ls.json")
  check "$RESP" "Logstash Logs+Metrics"
fi

###############################################################################
echo ""
echo "━━━ Docker Integration ━━━"
###############################################################################
E=$(exists "ELK-Docker-Metrics")
if [[ -n "$E" ]]; then
  echo "  ✅ Existe déjà (ID: $E)"
else
  cat > "$TMPDIR/dk.json" << 'EOF'
{
  "name": "ELK-Docker-Metrics",
  "description": "Docker container metrics",
  "namespace": "default",
  "policy_id": "fleet-server-policy",
  "package": { "name": "docker", "title": "Docker", "version": "2.15.0" },
  "inputs": [
    {
      "type": "docker/metrics",
      "enabled": true,
      "vars": {
        "hosts": { "value": ["unix:///var/run/docker.sock"], "type": "text" }
      },
      "streams": [
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "docker.container" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "docker.cpu" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "docker.diskio" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "docker.healthcheck" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "docker.info" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "docker.memory" }, "vars": { "period": { "value": "10s", "type": "text" } } },
        { "enabled": true, "data_stream": { "type": "metrics", "dataset": "docker.network" }, "vars": { "period": { "value": "10s", "type": "text" } } }
      ]
    },
    { "type": "filestream", "enabled": false, "streams": [] }
  ]
}
EOF
  RESP=$(api_post "${KIBANA}/api/fleet/package_policies" "$TMPDIR/dk.json")
  check "$RESP" "Docker Metrics"
fi

###############################################################################
echo ""
echo "━━━ Vérification fleet-server policy ━━━"
###############################################################################
curl -sk -u "$AUTH" -H "kbn-xsrf: true" "${KIBANA}/api/fleet/package_policies?perPage=100" \
  | jq -r --arg pid "$POLICY_ID" '.items[] | select(.policy_id==$pid) | "  • \(.name) [pkg: \(.package.name)]  (ID: \(.id))"'
