#!/bin/bash
# ===========================================================================
# Elasticsearch Backup Script
# ===========================================================================
# Description: Automated snapshot creation for Elasticsearch cluster
# Usage: ./backup-elasticsearch.sh [repository-name]
# Cron: 0 2 * * * /path/to/backup-elasticsearch.sh >> /var/log/es-backup.log 2>&1
# ===========================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_DIR}/.env"

# Load environment variables
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: .env file not found at $ENV_FILE"
    exit 1
fi

source "$ENV_FILE"

# Default values
ELASTICSEARCH_URL="${ELASTICSEARCH_URL:-https://localhost:9200}"
REPO_NAME="${1:-backup-repo}"
SNAPSHOT_NAME="snapshot-$(date +%Y%m%d-%H%M%S)"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

# Logging
LOG_FILE="${LOG_FILE:-/var/log/elasticsearch-backup.log}"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Check if repository exists
check_repository() {
    log "Checking if repository '$REPO_NAME' exists..."

    RESPONSE=$(curl -s -k -u "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" \
        -w "\n%{http_code}" \
        "${ELASTICSEARCH_URL}/_snapshot/${REPO_NAME}")

    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

    if [[ "$HTTP_CODE" -eq 404 ]]; then
        log "ERROR: Repository '$REPO_NAME' does not exist."
        log "Please create repository first. See documentation."
        exit 1
    elif [[ "$HTTP_CODE" -ne 200 ]]; then
        log "ERROR: Failed to check repository (HTTP $HTTP_CODE)"
        log "Response: $(echo "$RESPONSE" | head -n-1)"
        exit 1
    fi

    log "✓ Repository '$REPO_NAME' exists"
}

# Create snapshot
create_snapshot() {
    log "Creating snapshot '$SNAPSHOT_NAME' in repository '$REPO_NAME'..."

    RESPONSE=$(curl -s -k -u "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" \
        -w "\n%{http_code}" \
        -X PUT "${ELASTICSEARCH_URL}/_snapshot/${REPO_NAME}/${SNAPSHOT_NAME}" \
        -H 'Content-Type: application/json' \
        -d '{
            "indices": "*",
            "ignore_unavailable": true,
            "include_global_state": false,
            "metadata": {
                "taken_by": "backup-script",
                "taken_at": "'"$(date -Iseconds)"'"
            }
        }')

    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n-1)

    if [[ "$HTTP_CODE" -ne 200 ]]; then
        log "ERROR: Failed to create snapshot (HTTP $HTTP_CODE)"
        log "Response: $BODY"
        exit 1
    fi

    log "✓ Snapshot creation initiated: $SNAPSHOT_NAME"
}

# Wait for snapshot completion
wait_for_snapshot() {
    log "Waiting for snapshot to complete..."

    MAX_WAIT=3600  # 1 hour timeout
    ELAPSED=0
    SLEEP_INTERVAL=10

    while [[ $ELAPSED -lt $MAX_WAIT ]]; do
        RESPONSE=$(curl -s -k -u "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" \
            "${ELASTICSEARCH_URL}/_snapshot/${REPO_NAME}/${SNAPSHOT_NAME}")

        STATE=$(echo "$RESPONSE" | grep -o '"state":"[^"]*"' | cut -d'"' -f4)

        case "$STATE" in
            SUCCESS)
                log "✓ Snapshot completed successfully"
                return 0
                ;;
            IN_PROGRESS)
                log "  Snapshot in progress... (${ELAPSED}s elapsed)"
                sleep $SLEEP_INTERVAL
                ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
                ;;
            FAILED|PARTIAL)
                log "ERROR: Snapshot failed with state: $STATE"
                log "Response: $RESPONSE"
                exit 1
                ;;
            *)
                log "WARNING: Unknown snapshot state: $STATE"
                sleep $SLEEP_INTERVAL
                ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
                ;;
        esac
    done

    log "ERROR: Snapshot timed out after ${MAX_WAIT}s"
    exit 1
}

# Cleanup old snapshots
cleanup_old_snapshots() {
    log "Cleaning up snapshots older than $RETENTION_DAYS days..."

    CUTOFF_DATE=$(date -d "$RETENTION_DAYS days ago" +%Y%m%d)

    SNAPSHOTS=$(curl -s -k -u "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" \
        "${ELASTICSEARCH_URL}/_snapshot/${REPO_NAME}/_all" | \
        grep -o '"snapshot":"[^"]*"' | cut -d'"' -f4)

    DELETED_COUNT=0

    while IFS= read -r SNAPSHOT; do
        # Extract date from snapshot name (format: snapshot-YYYYMMDD-HHMMSS)
        if [[ "$SNAPSHOT" =~ snapshot-([0-9]{8})- ]]; then
            SNAPSHOT_DATE="${BASH_REMATCH[1]}"

            if [[ "$SNAPSHOT_DATE" -lt "$CUTOFF_DATE" ]]; then
                log "  Deleting old snapshot: $SNAPSHOT (date: $SNAPSHOT_DATE)"

                curl -s -k -u "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" \
                    -X DELETE "${ELASTICSEARCH_URL}/_snapshot/${REPO_NAME}/${SNAPSHOT}" \
                    > /dev/null

                DELETED_COUNT=$((DELETED_COUNT + 1))
            fi
        fi
    done <<< "$SNAPSHOTS"

    log "✓ Cleanup complete: $DELETED_COUNT snapshots deleted"
}

# Get snapshot statistics
get_snapshot_stats() {
    log "Fetching snapshot statistics..."

    RESPONSE=$(curl -s -k -u "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" \
        "${ELASTICSEARCH_URL}/_snapshot/${REPO_NAME}/${SNAPSHOT_NAME}")

    # Parse stats (requires jq for better parsing)
    if command -v jq &> /dev/null; then
        INDICES=$(echo "$RESPONSE" | jq -r '.snapshots[0].indices | length')
        SHARDS=$(echo "$RESPONSE" | jq -r '.snapshots[0].shards.total')
        SIZE=$(echo "$RESPONSE" | jq -r '.snapshots[0].stats.total.size_in_bytes')
        DURATION=$(echo "$RESPONSE" | jq -r '.snapshots[0].duration_in_millis')

        SIZE_MB=$((SIZE / 1024 / 1024))
        DURATION_MIN=$((DURATION / 1000 / 60))

        log "  Indices backed up: $INDICES"
        log "  Total shards: $SHARDS"
        log "  Backup size: ${SIZE_MB} MB"
        log "  Duration: ${DURATION_MIN} minutes"
    else
        log "  (Install jq for detailed statistics)"
    fi
}

# Main execution
main() {
    log "========================================="
    log "Elasticsearch Backup Started"
    log "========================================="
    log "Repository: $REPO_NAME"
    log "Snapshot: $SNAPSHOT_NAME"
    log "Retention: $RETENTION_DAYS days"
    log ""

    check_repository
    create_snapshot
    wait_for_snapshot
    get_snapshot_stats
    cleanup_old_snapshots

    log ""
    log "========================================="
    log "Backup Completed Successfully"
    log "========================================="
}

# Run main function
main "$@"
