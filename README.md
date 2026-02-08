<p align="center">
<img width="500px" src="https://user-images.githubusercontent.com/16992394/147855783-07b747f3-d033-476f-9e06-96a4a88a54c6.png">
</p>
<h2 align="center"><b>Elast</b>ic Stack on <b>Docker</b></h2>
<h3 align="center">Fleet-Managed with Security, Monitoring, and SIEM</h3>
<h4 align="center">Centralized log collection and monitoring with Elastic Fleet. Ready for Log, Metrics, APM, Alerting, Machine Learning, and Security (SIEM) use cases.</h4>
<p align="center">
   <a>
      <img src="https://img.shields.io/badge/Elastic%20Stack-9.2.3-blue?style=flat&logo=elasticsearch" alt="Elastic Stack Version 9^^">
   </a>
   <a>
      <img src="https://img.shields.io/github/v/tag/sherifabdlnaby/elastdocker?label=release&amp;sort=semver">
   </a>
   <a href="https://github.com/sherifabdlnaby/elastdocker/actions/workflows/build.yml">
      <img src="https://github.com/sherifabdlnaby/elastdocker/actions/workflows/build.yml/badge.svg">
   </a>
   <a>
      <img src="https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat" alt="contributions welcome">
   </a>
   <a href="https://github.com/sherifabdlnaby/elastdocker/network">
      <img src="https://img.shields.io/github/forks/sherifabdlnaby/elastdocker.svg" alt="GitHub forks">
   </a>
   <a href="https://github.com/sherifabdlnaby/elastdocker/issues">
        <img src="https://img.shields.io/github/issues/sherifabdlnaby/elastdocker.svg" alt="GitHub issues">
   </a>
   <a href="https://raw.githubusercontent.com/sherifabdlnaby/elastdocker/blob/master/LICENSE">
      <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="GitHub license">
   </a>
</p>

# Introduction
Elastic Stack (**ELK**) Docker Composition with **Elastic Fleet** for centralized agent management, preconfigured with **Security**, **Monitoring**, and **SIEM**; Up with a Single Command.

Suitable for Demoing, MVPs and small production deployments.

Stack Version: [9.2.3](https://www.elastic.co/guide/en/elasticsearch/reference/9.2/release-notes-9.2.3.html) - Based on [Official Elastic Docker Images](https://www.docker.elastic.co/)
> You can change Elastic Stack version by setting `ELK_VERSION` in `.env` file and rebuild your images. Any version >= 9.0.0 is compatible with this template.
>
> **Upgrading from 8.x?** See the [Upgrade Notes](#upgrade-notes-from-8x-to-9x) section below for breaking changes and migration steps.
---

## Architecture

```
                                   +------------------+
                                   |    Traefik       |
                                   |  (Reverse Proxy) |
                                   |   :80/:443/:8080 |
                                   +--------+---------+
                                            |
            +-------------------------------+-------------------------------+
            |                               |                               |
   +--------v--------+           +----------v---------+          +----------v---------+
   |  Elasticsearch  |           |       Kibana       |          |    Fleet Server    |
   |     :9200       |<--------->|       :5601        |<-------->|       :8220        |
   |  (Data Store)   |           |   (Web Interface)  |          | (Agent Management) |
   +--------+--------+           +--------------------+          +----------+---------+
            |                                                               |
            |                    +--------------------+                     |
            +<-------------------|     Logstash       |                     |
            |                    |    :5044/:9600     |                     |
            |                    | (Pipeline Engine)  |                     |
            |                    +--------------------+                     |
            |                                                               |
            |                    +--------------------+                     |
            +<-------------------|    APM Server      |                     |
                                 |       :8200        |                     |
                                 |  (App Monitoring)  |                     |
                                 +--------------------+                     |
                                                                            |
                    +---------------------------------------------------+   |
                    |                  Elastic Agents                    |  |
                    |  +-------------+  +-------------+  +-------------+ |  |
                    |  | fleet-server|  |     nuc     |  |    ibmac    |<---+
                    |  |   (local)   |  |  (remote)   |  |  (remote)   | |
                    |  +-------------+  +-------------+  +-------------+ |
                    +---------------------------------------------------+
```

### Main Features

- **Fleet-Managed Architecture** - Centralized agent management via Elastic Fleet
- **Security Enabled By Default** - TLS encryption, authentication, audit logging
- **Production Single Node Cluster** - With multi-node cluster option
- **Stack Monitoring via Fleet** - Elasticsearch, Kibana, Logstash metrics collected by Fleet integrations
- **Docker Metrics Collection** - Container monitoring via Docker integration
- **SIEM Ready** - 54 detection rules enabled (Linux/macOS/Network/Endpoint)
- **Automated Snapshots** - Daily SLM policy with 30-day retention
- **ILM Policies** - Automated index lifecycle management
- **Traefik Reverse Proxy** - HTTPS termination with auto-discovery
- **APM Server** - Application Performance Monitoring
- **Prometheus Exporters** - Legacy option for Grafana dashboards

### Fleet Integrations (Included)

| Integration | Description |
|-------------|-------------|
| **Elasticsearch** | Logs and Stack Monitoring metrics |
| **Kibana** | Logs and Stack Monitoring metrics |
| **Logstash** | Logs and Stack Monitoring metrics |
| **Docker** | Container metrics (7 metric streams) |
| **System** | Host logs and metrics |
| **Custom** | Asterisk SIP/Security logs (example) |


-----

# Requirements

- [Docker 20.05 or higher](https://docs.docker.com/install/) with Docker Compose v2
- 4GB RAM (For Windows and MacOS make sure Docker's VM has more than 4GB+ memory.)

# Setup

1. Clone the Repository
     ```bash
     git clone https://github.com/sherifabdlnaby/elastdocker.git
     ```
2. Initialize Elasticsearch Keystore and TLS Self-Signed Certificates
    ```bash
    make setup
    ```
    > **For Linux's docker hosts only**. By default virtual memory [is not enough](https://www.elastic.co/guide/en/elasticsearch/reference/current/vm-max-map-count.html) so run the next command as root `sysctl -w vm.max_map_count=262144`

3. Start Elastic Stack with Fleet Server
    ```bash
    make elk           # Core stack: ES, Kibana, Logstash, APM
    make fleet         # Add Fleet Server for agent management
    make traefik       # Add Traefik reverse proxy (optional)
    ```
    Or start everything at once:
    ```bash
    make all
    ```

4. Visit Kibana at [https://localhost:5601](https://localhost:5601) or via Traefik at `https://kibana.elastic.local`

    Default Username: `elastic`, Password: see `.env` file (`ELASTIC_PASSWORD`)

    > - Kibana uses HTTPS, so write `https://` before the URL
    > - Configure `/etc/hosts` for Traefik domains: `127.0.0.1 kibana.elastic.local elasticsearch.elastic.local`
    > - Modify `.env` for `ELASTIC_PASSWORD`, `ELASTICSEARCH_HEAP` & `LOGSTASH_HEAP`

5. Configure Fleet and enroll agents
    - Go to **Kibana > Fleet > Settings**
    - Fleet Server is pre-configured and running
    - Create agent policies and enroll remote hosts

## Docker Compose Files

| File | Description | Command |
|------|-------------|---------|
| `docker-compose.yml` | Core stack (ES, Kibana, Logstash, APM) | `make elk` |
| `docker-compose.fleet.yml` | Fleet Server with Docker socket | `make fleet` |
| `docker-compose.traefik.yml` | Traefik reverse proxy | `make traefik` |
| `docker-compose.monitor.yml` | Prometheus exporters (legacy) | `make monitoring` |
| `docker-compose.setup.yml` | Initial setup (certs, keystore) | `make setup` |
| `docker-compose.nodes.yml` | Extra ES nodes (experimental) | `make nodes` |

## Makefile Commands

| Command | Description |
|---------|-------------|
| `make elk` | Start core Elastic Stack |
| `make fleet` | Start Fleet Server |
| `make traefik` | Start Traefik reverse proxy |
| `make all` | Start everything (elk + fleet + traefik + monitoring) |
| `make monitoring` | Start Prometheus exporters (legacy) |
| `make nodes` | Add 2 extra ES nodes (experimental) |
| `make down` | Stop all containers |
| `make prune` | Remove all containers and **DELETE DATA** |
| `make setup` | Initialize certificates and keystore |
| `make build` | Rebuild images |

# Configuration

### Environment Variables (`.env`)

| Variable | Description | Default |
|----------|-------------|---------|
| `ELASTIC_PASSWORD` | Superuser password | `changeme` |
| `ELK_VERSION` | Elastic Stack version | `9.2.3` |
| `ELASTICSEARCH_HEAP` | ES heap size | `1g` |
| `LOGSTASH_HEAP` | Logstash heap size | `512m` |
| `CLUSTER_NAME` | Cluster name | `elastdocker-cluster` |
| `FLEET_SERVER_SERVICE_TOKEN` | Fleet Server token | (generated) |

### Configuration Files

| Component | Config File |
|-----------|-------------|
| Elasticsearch | `elasticsearch/config/elasticsearch.yml` |
| Kibana | `kibana/config/kibana.yml` |
| Logstash | `logstash/config/logstash.yml` |
| Logstash Pipelines | `logstash/pipeline/*.conf` |
| Traefik | `traefik/config/dynamic.yml` |

### Setting Up Keystore

Extend keystore with custom keys (e.g., S3 credentials):
```bash
# Edit setup/keystore.sh then:
make keystore
```

### Notes

- Elasticsearch uses HTTPS. Configure clients with CA from `secrets/certs/ca/ca.crt` or use `--insecure`
- Makefile wraps Docker Compose commands. Run `make help` for all commands
- Data persisted in `elasticsearch-data` volume
- Keystore and certificates generated in `./secrets` directory
- Re-run `make setup` after changing `ELASTIC_PASSWORD`
- Linux users: run as root `sysctl -w vm.max_map_count=262144`

---------------------------

![Intro](https://user-images.githubusercontent.com/16992394/156664447-c24c49f4-4282-4d6a-81a7-10743cfa384e.png)
![Alerting](https://user-images.githubusercontent.com/16992394/156664848-d14f5e58-8f80-497d-a841-914c05a4b69c.png)
![Maps](https://user-images.githubusercontent.com/16992394/156664562-d38e11ee-b033-4b91-80bd-3a866ad65f56.png)
![ML](https://user-images.githubusercontent.com/16992394/156664695-5c1ed4a7-82f3-47a6-ab5c-b0ce41cc0fbe.png)

# Working with Elastic APM

After completing the setup step, you will notice a container named apm-server which gives you deeper visibility into your applications and can help you to identify and resolve root cause issues with correlated traces, logs, and metrics.

## Authenticating with Elastic APM

In order to authenticate with Elastic APM, you will need the following:

- The value of `ELASTIC_APM_SECRET_TOKEN` defined in `.env` file as we have [secret token](https://www.elastic.co/guide/en/apm/guide/master/secret-token.html) enabled by default
- The ability to reach port `8200`
- Install elastic apm client in your application e.g. for NodeJS based applications you need to install [elastic-apm-node](https://www.elastic.co/guide/en/apm/agent/nodejs/master/typescript.html)
- Import the package in your application and call the start function, In case of NodeJS based application you can do the following:

```
const apm = require('elastic-apm-node').start({
  serviceName: 'foobar',
  secretToken: process.env.ELASTIC_APM_SECRET_TOKEN,
  
  // https is enabled by default as per elastdocker configuration
  serverUrl: 'https://localhost:8200',
})
```
> Make sure that the agent is started before you require any other modules in your Node.js application - i.e. before express, http, etc. as mentioned in [Elastic APM Agent - NodeJS initialization](https://www.elastic.co/guide/en/apm/agent/nodejs/master/express.html#express-initialization)

For more details or other languages you can check the following:
- [APM Agents in different languages](https://www.elastic.co/guide/en/apm/agent/index.html)

# Monitoring The Cluster

### Via Fleet Integrations (Recommended)

Stack Monitoring is now managed via **Fleet integrations**. The Fleet Server collects metrics from all stack components:

| Integration | Metrics Collected |
|-------------|-------------------|
| Elasticsearch | Cluster health, node stats, index stats, shard allocation |
| Kibana | Status, response times, concurrent connections |
| Logstash | Pipeline throughput, JVM metrics, queue stats |
| Docker | Container CPU, memory, network, disk I/O |
| System | Host CPU, memory, disk, network |

Head to **Stack Monitoring** tab in Kibana to see cluster metrics.

![Overview](https://user-images.githubusercontent.com/16992394/156664539-cc7e1a69-f1aa-4aca-93f6-7aedaabedd2c.png)
![Moniroting](https://user-images.githubusercontent.com/16992394/156664647-78cfe2af-489d-4c35-8963-9b0a46904cf7.png)

**Fleet Integrations Configuration:**
- Integrations are configured in Kibana > Fleet > Agent policies
- The `fleet-server-policy` includes ES, Kibana, Logstash, and Docker integrations
- Use Docker service names for internal communication (`elasticsearch:9200`, not `localhost`)

> In Production, cluster metrics should be shipped to another dedicated monitoring cluster.

### Via Prometheus Exporters (Legacy)

Prometheus exporters are still available for Grafana dashboards:

```bash
make monitoring
```

| **Prometheus Exporter**      | **Port**     | **Recommended Grafana Dashboard**                                         |
|--------------------------    |----------    |------------------------------------------------  |
| `elasticsearch-exporter`     | `9114`       | [Elasticsearch by Kristian Jensen](https://grafana.com/grafana/dashboards/4358)                                                |
| `logstash-exporter`          | `9304`       | [logstash-monitoring by dpavlos](https://github.com/dpavlos/logstash-monitoring)                                               |

![Metrics](https://user-images.githubusercontent.com/16992194/78685076-89a58900-78f1-11ea-959b-ce374fe51500.jpg)

---

# Fleet & Agent Management

Fleet Server enables centralized management of Elastic Agents across your infrastructure.

### Starting Fleet Server

```bash
make fleet
```

Fleet Server runs as a Docker container with the Docker socket mounted for container monitoring.

### Enrolling Remote Agents

1. Go to **Kibana > Fleet > Agents > Add agent**
2. Select or create an agent policy
3. Copy the enrollment command
4. Run on your remote host:

```bash
# Download and install Elastic Agent
curl -L -O https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-9.2.3-linux-x86_64.tar.gz
tar xzvf elastic-agent-9.2.3-linux-x86_64.tar.gz
cd elastic-agent-9.2.3-linux-x86_64

# Enroll with Fleet Server
sudo ./elastic-agent install \
  --url=https://<fleet-server-ip>:8220 \
  --enrollment-token=<your-token> \
  --insecure  # Only for self-signed certs
```

### Agent Policies

| Policy | Purpose |
|--------|---------|
| `fleet-server-policy` | Local Fleet Server + Stack Monitoring + Docker metrics |
| `Default policy` | General purpose for remote hosts |
| Custom policies | Create for specific use cases (e.g., Asterisk logs) |

---

# Security (SIEM)

### Detection Rules

This deployment includes **54 pre-enabled detection rules** filtered for:
- Linux and macOS systems
- Network and Endpoint domains
- Excludes Windows, Cloud-specific, and vendor-specific rules

View and manage rules in **Kibana > Security > Rules**.

### ILM Policies

Automated index lifecycle management:

| Policy | Hot Phase | Delete Phase | Applied To |
|--------|-----------|--------------|------------|
| `security-logs-lifecycle` | 90 days | 365 days | Auth logs, syslog |
| `system-logs-lifecycle` | 30 days | 90 days | System logs |
| `stack-monitoring-lifecycle` | 14 days | 30 days | Stack monitoring metrics |
| `metrics-lifecycle` | 30 days | 60 days | Docker, system metrics |

### Snapshots

Daily automated snapshots with SLM:

```bash
# Snapshot configuration
Repository: local-backups
Schedule: Daily at 2:00 AM
Retention: 30 days (min 5, max 30 snapshots)

# Manual snapshot
curl -sk -u elastic:$PASS -XPUT "https://localhost:9200/_slm/policy/daily-snapshots/_execute"
```

---

# Upgrade Notes from 8.x to 9.x

<details><summary>Expand to see breaking changes and migration details...</summary>
<p>

Elasticsearch 9 introduced several breaking changes. This section documents the changes made to ElastDocker for ES 9 compatibility.

## Breaking Changes Fixed

### 1. **Logstash Configuration Changes**

**File: `logstash/config/logstash.yml`**
- `http.host` → `api.http.host`

**File: `logstash/pipeline/main.conf`**
- `ssl` → `ssl_enabled`
- `ssl_certificate_verification` → `ssl_verification_mode`
- `cacert` → `ssl_certificate_authorities`

### 2. **Monitoring Architecture Change**

**Before (ES 8.x):**
- Used internal `xpack.monitoring.collection.enabled` setting
- Components self-reported metrics

**After (ES 9.x):**
- Uses external Metricbeat for metric collection
- More scalable and follows Elastic's recommended approach
- New component: `metricbeat` service in `docker-compose.monitor.yml`

**Files Modified:**
- `elasticsearch/config/elasticsearch.yml` - Removed `xpack.monitoring.collection.enabled`
- `logstash/config/logstash.yml` - Removed `xpack.monitoring` settings
- `apm-server/config/apm-server.yml` - Removed monitoring section
- `metricbeat/config/metricbeat.yml` - **NEW FILE** for Stack Monitoring

### 3. **Filebeat Migration to Filestream Input**

The `container` input type is deprecated in Filebeat 9. Migrated to the modern `filestream` input with container parser - the ES 9+ recommended approach.

**Files Modified:**
- `filebeat/filebeat.docker.logs.yml` - Now uses `type: filestream` with container parser
- `filebeat/filebeat.monitoring.yml` - All module inputs migrated to filestream

**Key Changes:**
- `type: container` → `type: filestream` with unique IDs
- Added `parsers.container` configuration for Docker log parsing
- Added `prospector.scanner.symlinks: true` for Docker log paths
- No deprecation warnings - fully ES 9 compliant

### 4. **Certificate Generation Script**

**File: `setup/setup-certs.sh`**
- Updated password generation to work without `openssl` command (not available in ES 9 containers)
- Now uses `/dev/urandom` for random password generation

### 5. **Elasticsearch Exporter Flags**

**File: `docker-compose.monitor.yml`**
- Updated exporter flags for compatibility with exporter v1.10.0+
- `--collector.indices` → `--es.indices`

## Known Deprecation Warnings

The following deprecation warnings are expected and originate from upstream Elastic components. They will be resolved in future component releases:

1. **Beats using `?local` parameter** (CRITICAL) - ~446 occurrences
   - Source: Metricbeat
   - Will be fixed in future Beats releases
   - **Note:** Filebeat no longer generates these warnings after migrating to filestream input

2. **Behavioral Analytics deprecated** (WARN) - ~37 occurrences
   - Source: Kibana cleanup process
   - Expected during ES 9 migration
   - Will resolve once cleanup completes

3. **APM System Index Access** (WARN) - ~13 occurrences
   - Source: APM Server
   - Will be fixed in future APM Server releases

These warnings don't affect functionality and are logged to the deprecation data stream for visibility.

## Upgrade Path

**Important:** You must upgrade to Elasticsearch 8.19.x before upgrading to 9.x.

**Recommended Path:**
```
8.17.0 → 8.19.x (run Upgrade Assistant) → 9.x
```

For a clean installation on ES 9, simply:
1. Set `ELK_VERSION=9.2.3` in `.env`
2. Run `make setup`
3. Run `make elk` (or `make all` for full stack with monitoring)

</p>
</details>

---

# License
[MIT License](https://raw.githubusercontent.com/sherifabdlnaby/elastdocker/master/LICENSE)
Copyright (c) 2022-2026 Sherif Abdel-Naby

# Contribution

PR(s) are Open and Welcomed.
