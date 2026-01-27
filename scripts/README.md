# ElasticDocker Scripts

Collection of automation scripts for managing and monitoring your Elasticsearch cluster.

## Available Scripts

### 1. backup-elasticsearch.sh

**Purpose:** Automated snapshot creation and retention management

**Usage:**
```bash
# Basic usage (uses default repository)
./scripts/backup-elasticsearch.sh

# Specify custom repository
./scripts/backup-elasticsearch.sh my-backup-repo

# Configure via environment variables
RETENTION_DAYS=60 LOG_FILE=/var/log/custom-backup.log ./scripts/backup-elasticsearch.sh
```

**Features:**
- ✅ Creates timestamped snapshots
- ✅ Validates repository existence
- ✅ Waits for completion with timeout
- ✅ Auto-cleanup old snapshots (default: 30 days)
- ✅ Detailed logging and statistics

**Cron Setup:**
```bash
# Daily backups at 2 AM
0 2 * * * /home/admsrv/elastdocker/scripts/backup-elasticsearch.sh >> /var/log/elasticsearch-backup.log 2>&1
```

**Prerequisites:**
1. Create snapshot repository first:
```bash
# Filesystem repository example
curl -X PUT "https://localhost:9200/_snapshot/backup-repo" \
  -u elastic:password --insecure \
  -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/usr/share/elasticsearch/backups"
  }
}'
```

---

### 2. health-check.sh

**Purpose:** Comprehensive health monitoring for entire ELK stack

**Usage:**
```bash
# Basic health check
./scripts/health-check.sh

# Verbose mode (includes top 10 indices)
./scripts/health-check.sh --verbose

# Enable alerting (email/Slack)
./scripts/health-check.sh --alerts

# Combined
./scripts/health-check.sh --verbose --alerts
```

**Features:**
- ✅ Cluster health (green/yellow/red status)
- ✅ Node statistics (heap, disk, CPU, GC)
- ✅ Logstash pipeline stats
- ✅ Kibana availability check
- ✅ Threshold-based alerting
- ✅ Color-coded console output

**Monitored Metrics:**
| Component | Metric | Threshold |
|-----------|--------|-----------|
| Elasticsearch | Heap Usage | 75% |
| Elasticsearch | Disk Usage | 80% |
| Elasticsearch | CPU Usage | 80% |
| Elasticsearch | GC Time | 10s |
| Logstash | Events Processing | N/A |
| Kibana | Status | green |

**Cron Setup:**
```bash
# Every 5 minutes with alerting
*/5 * * * * /home/admsrv/elastdocker/scripts/health-check.sh --alerts >> /var/log/elasticsearch-health.log 2>&1

# Hourly verbose check
0 * * * * /home/admsrv/elastdocker/scripts/health-check.sh --verbose >> /var/log/elasticsearch-health-verbose.log 2>&1
```

**Alert Configuration:**

Add to `.env`:
```bash
# Email alerting (requires mail command)
ALERT_EMAIL=admin@example.com

# Slack webhook
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

**Exit Codes:**
- `0` - OK (all systems healthy)
- `1` - WARNING (non-critical issues)
- `2` - CRITICAL (severe issues)

---

## Requirements

### System Dependencies
```bash
# Install required tools
sudo apt-get update
sudo apt-get install -y curl jq

# Optional for email alerts
sudo apt-get install -y mailutils
```

### Permissions
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Optional: Add to PATH
export PATH="$PATH:/home/admsrv/elastdocker/scripts"
```

---

## Configuration

All scripts read configuration from `.env` file in project root.

**Required variables:**
```bash
ELASTIC_USERNAME=elastic
ELASTIC_PASSWORD=your-strong-password
ELASTICSEARCH_HOST=elasticsearch
ELASTICSEARCH_PORT=9200
```

**Optional variables:**
```bash
# Custom URLs (if not using defaults)
ELASTICSEARCH_URL=https://localhost:9200
LOGSTASH_URL=http://localhost:9600
KIBANA_URL=https://localhost:5601

# Backup settings
RETENTION_DAYS=30
LOG_FILE=/var/log/elasticsearch-backup.log

# Alerting
ALERT_EMAIL=admin@example.com
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/XXX/YYY/ZZZ
```

---

## Monitoring & Alerting Setup

### Email Alerts

1. **Install mailutils:**
```bash
sudo apt-get install mailutils
```

2. **Configure SMTP (optional):**
Edit `/etc/postfix/main.cf`:
```
relayhost = [smtp.gmail.com]:587
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_security_level = encrypt
```

3. **Test email:**
```bash
echo "Test" | mail -s "Test Email" admin@example.com
```

### Slack Alerts

1. **Create Slack Incoming Webhook:**
   - Go to https://api.slack.com/apps
   - Create new app → Incoming Webhooks
   - Activate and add webhook to workspace
   - Copy webhook URL

2. **Add to .env:**
```bash
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX
```

3. **Test webhook:**
```bash
curl -X POST "$SLACK_WEBHOOK_URL" \
  -H 'Content-Type: application/json' \
  -d '{"text":"ElasticStack monitoring test"}'
```

---

## Troubleshooting

### Script fails with "Cannot connect to Elasticsearch"

**Check:**
1. Elasticsearch is running: `docker ps | grep elasticsearch`
2. Correct URL in .env
3. Valid credentials
4. SSL certificate issues: Use `--insecure` flag

**Solution:**
```bash
# Test connection manually
curl -k -u elastic:password https://localhost:9200/_cluster/health

# Check Docker network
docker network inspect elastic
```

### "Repository not found" error

**Create repository first:**
```bash
# Filesystem repository
docker exec elasticsearch mkdir -p /usr/share/elasticsearch/backups

curl -X PUT "https://localhost:9200/_snapshot/backup-repo" \
  -k -u elastic:password \
  -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/usr/share/elasticsearch/backups",
    "compress": true
  }
}'
```

### "jq command not found"

**Install jq:**
```bash
sudo apt-get install jq
```

Scripts work without jq but provide less detailed output.

---

## Best Practices

### Backup Strategy

**3-2-1 Rule:**
- 3 copies of data
- 2 different storage types
- 1 offsite backup

**Recommended Schedule:**
```bash
# Daily incremental backups
0 2 * * * /path/to/backup-elasticsearch.sh daily-repo

# Weekly full backups to remote storage
0 3 * * 0 /path/to/backup-elasticsearch.sh weekly-s3-repo

# Monthly archives
0 4 1 * * /path/to/backup-elasticsearch.sh monthly-archive
```

### Monitoring Strategy

**Multi-tier monitoring:**
```bash
# Tier 1: Continuous (every 5 min) with alerts
*/5 * * * * ./health-check.sh --alerts

# Tier 2: Detailed hourly reports
0 * * * * ./health-check.sh --verbose

# Tier 3: Daily summary email
0 8 * * * ./health-check.sh --verbose --alerts | mail -s "Daily ElasticStack Report" admin@example.com
```

### Security

**Protect credentials:**
```bash
# Secure .env file
chmod 600 .env

# Secure log files
chmod 640 /var/log/elasticsearch-*.log
chown elasticsearch:elasticsearch /var/log/elasticsearch-*.log
```

**Use Docker secrets instead of .env in production:**
```yaml
# docker-compose.yml
secrets:
  elastic_password:
    external: true
```

---

## Advanced Usage

### Custom Snapshot Repository (S3)

```bash
# Install S3 repository plugin
docker exec elasticsearch bin/elasticsearch-plugin install repository-s3

# Configure S3 credentials in keystore
docker exec elasticsearch bin/elasticsearch-keystore add s3.client.default.access_key
docker exec elasticsearch bin/elasticsearch-keystore add s3.client.default.secret_key

# Restart Elasticsearch
docker restart elasticsearch

# Create S3 repository
curl -X PUT "https://localhost:9200/_snapshot/s3-backup" \
  -k -u elastic:password \
  -H 'Content-Type: application/json' -d'
{
  "type": "s3",
  "settings": {
    "bucket": "elasticsearch-backups",
    "region": "us-east-1",
    "compress": true
  }
}'

# Use with backup script
./scripts/backup-elasticsearch.sh s3-backup
```

### Restore from Backup

```bash
# List available snapshots
curl -k -u elastic:password \
  "https://localhost:9200/_snapshot/backup-repo/_all?pretty"

# Restore specific snapshot
curl -X POST "https://localhost:9200/_snapshot/backup-repo/snapshot-20250127-020000/_restore" \
  -k -u elastic:password \
  -H 'Content-Type: application/json' -d'
{
  "indices": "*",
  "ignore_unavailable": true,
  "include_global_state": false
}'

# Monitor restoration progress
curl -k -u elastic:password \
  "https://localhost:9200/_cat/recovery?v&active_only=true"
```

---

## Contributing

To add new scripts:

1. **Follow naming convention:** `verb-noun.sh` (e.g., `optimize-indices.sh`)
2. **Include header documentation:**
```bash
#!/bin/bash
# ===========================================================================
# Script Name
# ===========================================================================
# Description: What does this script do
# Usage: ./script-name.sh [options]
# ===========================================================================
```

3. **Make executable:** `chmod +x scripts/new-script.sh`
4. **Add to this README**
5. **Test thoroughly before committing**

---

## License

MIT License - See main project LICENSE file

---

## Support

For issues or questions:
- GitHub Issues: https://github.com/sherifabdlnaby/elastdocker/issues
- Project Documentation: See CLAUDE.md for detailed architecture
- Elasticsearch Docs: https://www.elastic.co/guide/

---

**Last Updated:** 2025-01-27
