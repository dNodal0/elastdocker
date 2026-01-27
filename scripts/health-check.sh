#!/bin/bash
# ===========================================================================
# Elasticsearch Health Check Script
# ===========================================================================
# Description: Comprehensive health monitoring for Elasticsearch cluster
# Usage: ./health-check.sh [--verbose] [--alerts]
# Cron: */5 * * * * /path/to/health-check.sh --alerts >> /var/log/es-health.log 2>&1
# ===========================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_DIR}/.env"

# Command line options
VERBOSE=false
ALERTS_ENABLED=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --alerts|-a)
            ALERTS_ENABLED=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--verbose] [--alerts]"
            exit 1
            ;;
    esac
done

# Load environment variables
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: .env file not found at $ENV_FILE"
    exit 1
fi

source "$ENV_FILE"

# Default values
ELASTICSEARCH_URL="${ELASTICSEARCH_URL:-https://localhost:9200}"
LOGSTASH_URL="${LOGSTASH_URL:-http://localhost:9600}"
KIBANA_URL="${KIBANA_URL:-https://localhost:5601}"

# Thresholds
HEAP_THRESHOLD=75
DISK_THRESHOLD=80
CPU_THRESHOLD=80
GC_TIME_THRESHOLD=10000  # milliseconds

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'  # No Color

# Status tracking
OVERALL_STATUS="OK"
ISSUES=()

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
    OVERALL_STATUS="WARNING"
    ISSUES+=("$*")
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
    OVERALL_STATUS="CRITICAL"
    ISSUES+=("$*")
}

# Check Elasticsearch cluster health
check_elasticsearch() {
    echo ""
    echo "========================================="
    echo "Elasticsearch Cluster Health"
    echo "========================================="

    if ! RESPONSE=$(curl -s -k -u "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" \
        "${ELASTICSEARCH_URL}/_cluster/health" 2>&1); then
        log_error "Cannot connect to Elasticsearch at $ELASTICSEARCH_URL"
        return 1
    fi

    # Parse cluster status
    if command -v jq &> /dev/null; then
        CLUSTER_NAME=$(echo "$RESPONSE" | jq -r '.cluster_name')
        CLUSTER_STATUS=$(echo "$RESPONSE" | jq -r '.status')
        NODES=$(echo "$RESPONSE" | jq -r '.number_of_nodes')
        ACTIVE_SHARDS=$(echo "$RESPONSE" | jq -r '.active_shards')
        RELOCATING_SHARDS=$(echo "$RESPONSE" | jq -r '.relocating_shards')
        INITIALIZING_SHARDS=$(echo "$RESPONSE" | jq -r '.initializing_shards')
        UNASSIGNED_SHARDS=$(echo "$RESPONSE" | jq -r '.unassigned_shards')

        echo "Cluster: $CLUSTER_NAME"
        echo "Status: $CLUSTER_STATUS"
        echo "Nodes: $NODES"
        echo "Shards: $ACTIVE_SHARDS active, $RELOCATING_SHARDS relocating, $UNASSIGNED_SHARDS unassigned"

        case "$CLUSTER_STATUS" in
            green)
                log_info "Cluster status is GREEN - All good!"
                ;;
            yellow)
                log_warn "Cluster status is YELLOW - Replicas not allocated"
                ;;
            red)
                log_error "Cluster status is RED - Primary shards unavailable!"
                ;;
        esac

        if [[ "$UNASSIGNED_SHARDS" -gt 0 ]]; then
            log_warn "Found $UNASSIGNED_SHARDS unassigned shards"
        fi
    else
        echo "$RESPONSE"
        log_warn "Install jq for detailed health parsing"
    fi
}

# Check Elasticsearch nodes stats
check_elasticsearch_nodes() {
    echo ""
    echo "========================================="
    echo "Elasticsearch Nodes Statistics"
    echo "========================================="

    if ! RESPONSE=$(curl -s -k -u "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" \
        "${ELASTICSEARCH_URL}/_nodes/stats" 2>&1); then
        log_error "Cannot fetch node stats"
        return 1
    fi

    if command -v jq &> /dev/null; then
        # Parse each node
        NODE_IDS=$(echo "$RESPONSE" | jq -r '.nodes | keys[]')

        while IFS= read -r NODE_ID; do
            NODE_NAME=$(echo "$RESPONSE" | jq -r ".nodes[\"$NODE_ID\"].name")

            # Heap usage
            HEAP_PERCENT=$(echo "$RESPONSE" | jq -r ".nodes[\"$NODE_ID\"].jvm.mem.heap_used_percent")

            # Disk usage
            DISK_TOTAL=$(echo "$RESPONSE" | jq -r ".nodes[\"$NODE_ID\"].fs.total.total_in_bytes")
            DISK_AVAILABLE=$(echo "$RESPONSE" | jq -r ".nodes[\"$NODE_ID\"].fs.total.available_in_bytes")
            DISK_PERCENT=$(awk "BEGIN {printf \"%.0f\", (($DISK_TOTAL - $DISK_AVAILABLE) / $DISK_TOTAL) * 100}")

            # CPU usage
            CPU_PERCENT=$(echo "$RESPONSE" | jq -r ".nodes[\"$NODE_ID\"].os.cpu.percent")

            # GC stats
            GC_TIME=$(echo "$RESPONSE" | jq -r ".nodes[\"$NODE_ID\"].jvm.gc.collectors.old.collection_time_in_millis")

            echo ""
            echo "Node: $NODE_NAME"
            echo "  Heap: ${HEAP_PERCENT}%"
            echo "  Disk: ${DISK_PERCENT}%"
            echo "  CPU: ${CPU_PERCENT}%"
            echo "  GC Time: ${GC_TIME}ms"

            # Check thresholds
            if [[ "$HEAP_PERCENT" -gt "$HEAP_THRESHOLD" ]]; then
                log_warn "Node $NODE_NAME: High heap usage (${HEAP_PERCENT}% > ${HEAP_THRESHOLD}%)"
            fi

            if [[ "$DISK_PERCENT" -gt "$DISK_THRESHOLD" ]]; then
                log_error "Node $NODE_NAME: High disk usage (${DISK_PERCENT}% > ${DISK_THRESHOLD}%)"
            fi

            if [[ "$CPU_PERCENT" -gt "$CPU_THRESHOLD" ]]; then
                log_warn "Node $NODE_NAME: High CPU usage (${CPU_PERCENT}% > ${CPU_THRESHOLD}%)"
            fi

            if [[ "$GC_TIME" -gt "$GC_TIME_THRESHOLD" ]]; then
                log_warn "Node $NODE_NAME: High GC time (${GC_TIME}ms > ${GC_TIME_THRESHOLD}ms)"
            fi

        done <<< "$NODE_IDS"
    else
        log_warn "Install jq for detailed node statistics"
    fi
}

# Check Logstash health
check_logstash() {
    echo ""
    echo "========================================="
    echo "Logstash Health"
    echo "========================================="

    if ! RESPONSE=$(curl -s "${LOGSTASH_URL}/_node/stats" 2>&1); then
        log_warn "Cannot connect to Logstash at $LOGSTASH_URL"
        return 1
    fi

    if command -v jq &> /dev/null; then
        LOGSTASH_VERSION=$(echo "$RESPONSE" | jq -r '.version')
        PIPELINE_WORKERS=$(echo "$RESPONSE" | jq -r '.pipeline.workers')
        EVENTS_IN=$(echo "$RESPONSE" | jq -r '.events.in')
        EVENTS_OUT=$(echo "$RESPONSE" | jq -r '.events.out')
        EVENTS_FILTERED=$(echo "$RESPONSE" | jq -r '.events.filtered')

        echo "Version: $LOGSTASH_VERSION"
        echo "Pipeline Workers: $PIPELINE_WORKERS"
        echo "Events In: $EVENTS_IN"
        echo "Events Out: $EVENTS_OUT"
        echo "Events Filtered: $EVENTS_FILTERED"

        if [[ "$EVENTS_OUT" -eq 0 ]] && [[ "$EVENTS_IN" -gt 0 ]]; then
            log_warn "Logstash processing events but no output (check pipelines)"
        else
            log_info "Logstash is processing events normally"
        fi
    else
        echo "$RESPONSE"
        log_warn "Install jq for detailed Logstash parsing"
    fi
}

# Check Kibana health
check_kibana() {
    echo ""
    echo "========================================="
    echo "Kibana Health"
    echo "========================================="

    if ! RESPONSE=$(curl -s -k "${KIBANA_URL}/api/status" 2>&1); then
        log_warn "Cannot connect to Kibana at $KIBANA_URL"
        return 1
    fi

    if command -v jq &> /dev/null; then
        KIBANA_STATUS=$(echo "$RESPONSE" | jq -r '.status.overall.state')
        KIBANA_VERSION=$(echo "$RESPONSE" | jq -r '.version.number')

        echo "Version: $KIBANA_VERSION"
        echo "Status: $KIBANA_STATUS"

        if [[ "$KIBANA_STATUS" == "green" ]]; then
            log_info "Kibana is healthy"
        else
            log_warn "Kibana status is $KIBANA_STATUS"
        fi
    else
        echo "$RESPONSE"
        log_warn "Install jq for detailed Kibana parsing"
    fi
}

# Check indices
check_indices() {
    if [[ "$VERBOSE" != "true" ]]; then
        return
    fi

    echo ""
    echo "========================================="
    echo "Elasticsearch Indices (Top 10 by size)"
    echo "========================================="

    if ! RESPONSE=$(curl -s -k -u "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" \
        "${ELASTICSEARCH_URL}/_cat/indices?v&s=store.size:desc&h=index,status,health,docs.count,store.size" | head -n 11); then
        log_error "Cannot fetch indices"
        return 1
    fi

    echo "$RESPONSE"
}

# Send alerts
send_alert() {
    if [[ "$ALERTS_ENABLED" != "true" ]] || [[ "$OVERALL_STATUS" == "OK" ]]; then
        return
    fi

    # Email alert (requires mailx or sendmail configured)
    if command -v mail &> /dev/null && [[ -n "${ALERT_EMAIL:-}" ]]; then
        {
            echo "Elasticsearch Health Check Alert"
            echo ""
            echo "Status: $OVERALL_STATUS"
            echo "Timestamp: $(date)"
            echo ""
            echo "Issues:"
            printf '%s\n' "${ISSUES[@]}"
        } | mail -s "[ElasticStack] Health Alert - $OVERALL_STATUS" "$ALERT_EMAIL"
    fi

    # Slack webhook (if configured)
    if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
        ISSUES_TEXT=$(printf '%s\\n' "${ISSUES[@]}")

        curl -s -X POST "$SLACK_WEBHOOK_URL" \
            -H 'Content-Type: application/json' \
            -d "{
                \"text\": \"🚨 Elasticsearch Health Alert\",
                \"attachments\": [{
                    \"color\": \"danger\",
                    \"fields\": [
                        {\"title\": \"Status\", \"value\": \"$OVERALL_STATUS\", \"short\": true},
                        {\"title\": \"Timestamp\", \"value\": \"$(date)\", \"short\": true},
                        {\"title\": \"Issues\", \"value\": \"$ISSUES_TEXT\", \"short\": false}
                    ]
                }]
            }" > /dev/null
    fi
}

# Main execution
main() {
    echo "╔═══════════════════════════════════════╗"
    echo "║  Elasticsearch Stack Health Check    ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""
    echo "Timestamp: $(date)"

    check_elasticsearch
    check_elasticsearch_nodes
    check_logstash
    check_kibana
    check_indices

    echo ""
    echo "========================================="
    echo "Overall Status: $OVERALL_STATUS"
    echo "========================================="

    if [[ "${#ISSUES[@]}" -eq 0 ]]; then
        log_info "No issues detected - All systems operational!"
    else
        echo ""
        echo "Issues found:"
        printf '  - %s\n' "${ISSUES[@]}"
    fi

    send_alert

    # Exit code based on status
    case "$OVERALL_STATUS" in
        OK)
            exit 0
            ;;
        WARNING)
            exit 1
            ;;
        CRITICAL)
            exit 2
            ;;
    esac
}

# Run main function
main "$@"
