.DEFAULT_GOAL:=help

include .env

# Compose file combinations
COMPOSE_ELK := -f docker-compose.yml
COMPOSE_FLEET := -f docker-compose.yml -f docker-compose.fleet.yml
COMPOSE_TRAEFIK := -f docker-compose.yml -f docker-compose.traefik.yml
COMPOSE_GRAFANA := -f docker-compose.yml -f docker-compose.grafana.yml
COMPOSE_MONITORING := -f docker-compose.yml -f docker-compose.monitor.yml
COMPOSE_NODES := -f docker-compose.yml -f docker-compose.nodes.yml
COMPOSE_ALL_FILES := -f docker-compose.yml -f docker-compose.fleet.yml -f docker-compose.traefik.yml -f docker-compose.grafana.yml -f docker-compose.monitor.yml -f docker-compose.nodes.yml

# Services
ELK_SERVICES   := elasticsearch logstash kibana apm-server
ELK_FLEET := fleet-server
ELK_TRAEFIK := traefik
ELK_GRAFANA := grafana
ELK_MONITORING := elasticsearch-exporter logstash-exporter
ELK_NODES := elasticsearch-1 elasticsearch-2
ELK_MAIN_SERVICES := ${ELK_SERVICES} ${ELK_FLEET} ${ELK_TRAEFIK} ${ELK_GRAFANA} ${ELK_MONITORING}
ELK_ALL_SERVICES := ${ELK_MAIN_SERVICES} ${ELK_NODES}

DOCKER_COMPOSE_COMMAND = docker compose

# --------------------------
.PHONY: setup keystore certs all elk fleet traefik grafana monitoring build down stop restart rm logs

keystore:		## Setup Elasticsearch Keystore, by initializing passwords, and add credentials defined in `keystore.sh`.
	$(DOCKER_COMPOSE_COMMAND) -f docker-compose.setup.yml run --rm keystore

upgrade-keystore:	## Upgrade Elasticsearch Keystore, which is necessary when upgrading to an Elasticsearch version that uses a newer Java version.
	@if [ -n "$$($(DOCKER_COMPOSE_COMMAND) ps -q)" ]; then \
		echo "Please stop all running containers before upgrading the keystore."; \
		exit 1; \
	fi
	$(DOCKER_COMPOSE_COMMAND) -f docker-compose.setup.yml run --rm upgrade-keystore

certs:		    ## Generate Elasticsearch SSL Certs.
	$(DOCKER_COMPOSE_COMMAND) -f docker-compose.setup.yml run --rm certs

setup:		    ## Generate Elasticsearch SSL Certs and Keystore.
	@make certs
	@make keystore

all:		    ## Start everything: ELK + Fleet + Traefik + Monitoring.
	$(DOCKER_COMPOSE_COMMAND) ${COMPOSE_ALL_FILES} up -d --build ${ELK_MAIN_SERVICES}

elk:		    ## Start core ELK stack (ES, Kibana, Logstash, APM).
	$(DOCKER_COMPOSE_COMMAND) ${COMPOSE_ELK} up -d --build

fleet:		    ## Start Fleet Server for agent management.
	$(DOCKER_COMPOSE_COMMAND) ${COMPOSE_FLEET} up -d --build ${ELK_FLEET}

traefik:	    ## Start Traefik reverse proxy with ELK.
	$(DOCKER_COMPOSE_COMMAND) ${COMPOSE_TRAEFIK} up -d --build ${ELK_TRAEFIK}

grafana:	    ## Start Grafana dashboards.
	$(DOCKER_COMPOSE_COMMAND) ${COMPOSE_GRAFANA} up -d --build ${ELK_GRAFANA}

up:
	@make elk
	@echo "Visit Kibana: https://localhost:5601 (user: elastic, password: changeme) [Unless you changed values in .env]"

monitoring:		## Start Prometheus exporters (legacy).
	$(DOCKER_COMPOSE_COMMAND) ${COMPOSE_MONITORING} up -d --build ${ELK_MONITORING}


nodes:		    ## Start Two Extra Elasticsearch Nodes
	$(DOCKER_COMPOSE_COMMAND) ${COMPOSE_NODES} up -d --build ${ELK_NODES}

build:			## Build ELK and all its extra components.
	$(DOCKER_COMPOSE_COMMAND) ${COMPOSE_ALL_FILES} build ${ELK_ALL_SERVICES}
ps:				## Show all running containers.
	$(DOCKER_COMPOSE_COMMAND) ${COMPOSE_ALL_FILES} ps

down:			## Down ELK and all its extra components.
	$(DOCKER_COMPOSE_COMMAND) ${COMPOSE_ALL_FILES} down

stop:			## Stop ELK and all its extra components.
	$(DOCKER_COMPOSE_COMMAND) ${COMPOSE_ALL_FILES} stop ${ELK_ALL_SERVICES}
	
restart:		## Restart ELK and all its extra components.
	$(DOCKER_COMPOSE_COMMAND) ${COMPOSE_ALL_FILES} restart ${ELK_ALL_SERVICES}

rm:				## Remove ELK and all its extra components containers.
	$(DOCKER_COMPOSE_COMMAND) $(COMPOSE_ALL_FILES) rm -f ${ELK_ALL_SERVICES}

logs:			## Tail all logs with -n 1000.
	$(DOCKER_COMPOSE_COMMAND) $(COMPOSE_ALL_FILES) logs --follow --tail=1000 ${ELK_ALL_SERVICES}

images:			## Show all Images of ELK and all its extra components.
	$(DOCKER_COMPOSE_COMMAND) $(COMPOSE_ALL_FILES) images ${ELK_ALL_SERVICES}

prune:			## Remove ELK Containers and Delete ELK-related Volume Data (the elastic_elasticsearch-data volume)
	@make stop && make rm
	@docker volume ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format "{{.Name}}" | xargs docker volume rm 2>/dev/null || true
	@echo "Removed all volumes for project: ${COMPOSE_PROJECT_NAME}"

help:       	## Show this help.
	@echo "Make Application Docker Images and Containers using Docker Compose (v2) files."
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m (default: help)\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
