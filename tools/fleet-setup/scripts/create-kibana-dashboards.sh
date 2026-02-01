#!/bin/bash
###################### Elastic Agent - Create Kibana Dashboards ######################
# Purpose: Créer les dashboards de sécurité pour fail2ban, Asterisk, auth/SSH
# Usage: ELASTIC_PASSWORD='xxx' ./create-kibana-dashboards.sh

set -e

# Configuration
KIBANA="${KIBANA_HOST:-https://kibana.elastic.local}"
ES_USER="${ELASTIC_USERNAME:-elastic}"
ES_PASS="${ELASTIC_PASSWORD}"

if [ -z "$ES_PASS" ]; then
    echo "❌ ELASTIC_PASSWORD non défini"
    exit 1
fi

echo "🔧 Création Dashboards Kibana - Sécurité"
echo "   Kibana: $KIBANA"
echo ""

# Test connexion
echo "🔍 Test connexion Kibana..."
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" \
  -u "$ES_USER:$ES_PASS" \
  -H "kbn-xsrf: true" \
  "${KIBANA}/api/status")

if [ "$HTTP_CODE" != "200" ]; then
    echo "❌ Connexion échouée (HTTP $HTTP_CODE)"
    exit 1
fi
echo "✅ Connexion OK"
echo ""

#========================= DATA VIEW ========================================

echo "📋 Création Data View logs-*-security*..."

RESPONSE=$(curl -k -s -w "\n%{http_code}" \
  -u "$ES_USER:$ES_PASS" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -X POST "${KIBANA}/api/data_views/data_view" \
  -d '{
    "data_view": {
      "id": "1ff23f8d-3efa-4f7d-8796-57a76c624160",
      "title": "logs-*-security*",
      "timeFieldName": "@timestamp",
      "name": "Security Logs"
    }
  }')

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "  ✅ Data View créé"
elif echo "$RESPONSE" | grep -qi "exists\|duplicate\|conflict"; then
    echo "  ⚠️  Data View existe déjà"
else
    echo "  ⚠️  HTTP ${HTTP_CODE} - tentative avec ancien format..."
    curl -k -s -o /dev/null \
      -u "$ES_USER:$ES_PASS" \
      -H "kbn-xsrf: true" \
      -H "Content-Type: application/json" \
      -X POST "${KIBANA}/api/index_patterns/index_pattern" \
      -d '{
        "index_pattern": {
          "id": "1ff23f8d-3efa-4f7d-8796-57a76c624160",
          "title": "logs-*-security*",
          "timeFieldName": "@timestamp"
        }
      }' && echo "  ✅ Index Pattern créé (legacy)" || echo "  ⚠️  Continuons sans data view"
fi
echo ""

#========================= DASHBOARDS ========================================

echo "📋 Import des dashboards via Saved Objects API..."

NDJSON_PAYLOAD=$(cat <<'ENDNDJSON'
{"type":"visualization","id":"sec-viz-attacks-timeline","attributes":{"title":"[Security] Attaques par jour","visState":"{\"title\":\"Attaques par jour\",\"type\":\"line\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"date_histogram\",\"params\":{\"field\":\"@timestamp\",\"timeRange\":{\"from\":\"now-30d\",\"to\":\"now\"},\"useNormalizedEsInterval\":true,\"scaleMetricValues\":false,\"interval\":\"1d\",\"drop_partials\":false,\"min_doc_count\":1,\"extended_bounds\":{}},\"schema\":\"segment\"},{\"id\":\"3\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"log_type\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":5},\"schema\":\"group\"}],\"params\":{\"type\":\"line\",\"grid\":{\"categoryLines\":false},\"categoryAxes\":[{\"id\":\"CategoryAxis-1\",\"type\":\"category\",\"position\":\"bottom\",\"show\":true,\"labels\":{\"show\":true,\"filter\":true,\"truncate\":100}}],\"valueAxes\":[{\"id\":\"ValueAxis-1\",\"name\":\"LeftAxis-1\",\"type\":\"value\",\"position\":\"left\",\"show\":true,\"labels\":{\"show\":true,\"filter\":false,\"truncate\":100}}],\"addTooltip\":true,\"addLegend\":true,\"legendPosition\":\"top\"}}","kibanaSavedObjectMeta":{"searchSourceJSON":"{\"index\":\"1ff23f8d-3efa-4f7d-8796-57a76c624160\",\"query\":{\"query\":\"event.category:security\",\"language\":\"kuery\"},\"filter\":[]}"},"description":"Évolution des attaques par jour et par type"},"references":[{"id":"1ff23f8d-3efa-4f7d-8796-57a76c624160","name":"kibanaSavedObjectMeta.searchSourceJSON.index","type":"index-pattern"}]}
{"type":"visualization","id":"sec-viz-top-attackers","attributes":{"title":"[Security] Top 20 IPs attaquantes","visState":"{\"title\":\"Top 20 IPs attaquantes\",\"type\":\"table\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"attacker_ip\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":20},\"schema\":\"bucket\"},{\"id\":\"3\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"geoip.country_name\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":1},\"schema\":\"bucket\"},{\"id\":\"4\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"log_type\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":5},\"schema\":\"bucket\"}],\"params\":{\"perPage\":20,\"showPartialRows\":false,\"showMetricsAtAllLevels\":false,\"showTotal\":true,\"totalFunc\":\"sum\"}}","kibanaSavedObjectMeta":{"searchSourceJSON":"{\"index\":\"1ff23f8d-3efa-4f7d-8796-57a76c624160\",\"query\":{\"query\":\"attacker_ip:*\",\"language\":\"kuery\"},\"filter\":[]}"},"description":"Top 20 IPs avec pays et type d'attaque"},"references":[{"id":"1ff23f8d-3efa-4f7d-8796-57a76c624160","name":"kibanaSavedObjectMeta.searchSourceJSON.index","type":"index-pattern"}]}
{"type":"visualization","id":"sec-viz-geo-map","attributes":{"title":"[Security] Carte GeoIP attaques","visState":"{\"title\":\"Carte GeoIP attaques\",\"type\":\"region_map\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"geoip.country_iso_code\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":50},\"schema\":\"segment\"}],\"params\":{\"legendPosition\":\"bottomright\",\"addTooltip\":true,\"colorSchema\":\"Reds\",\"selectedLayer\":{\"name\":\"World Countries\",\"attribution\":\"<a href=\\\"http://www.naturalearthdata.com/about/terms-of-use\\\">Made with NaturalEarth</a>\",\"format\":{\"type\":\"geojson\"},\"layerType\":\"vector\",\"created_at\":\"2017-04-26T17:12:15.978370\",\"id\":\"5765733831234567\",\"fields\":[{\"name\":\"iso2\",\"description\":\"Two letter abbreviation\",\"type\":\"id\"},{\"name\":\"name\",\"description\":\"Country name\",\"type\":\"id\"}],\"isEMS\":true},\"selectedJoinField\":{\"name\":\"iso2\",\"description\":\"Two letter abbreviation\"},\"isDisplayWarning\":false,\"wms\":{\"enabled\":false},\"mapZoom\":2,\"mapCenter\":[0,0]}}","kibanaSavedObjectMeta":{"searchSourceJSON":"{\"index\":\"1ff23f8d-3efa-4f7d-8796-57a76c624160\",\"query\":{\"query\":\"geoip.country_iso_code:*\",\"language\":\"kuery\"},\"filter\":[]}"},"description":"Carte mondiale des attaques par pays"},"references":[{"id":"1ff23f8d-3efa-4f7d-8796-57a76c624160","name":"kibanaSavedObjectMeta.searchSourceJSON.index","type":"index-pattern"}]}
{"type":"visualization","id":"sec-viz-attack-types","attributes":{"title":"[Security] Types d'attaques","visState":"{\"title\":\"Types d'attaques\",\"type\":\"pie\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"event.type\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":10},\"schema\":\"segment\"}],\"params\":{\"type\":\"pie\",\"addTooltip\":true,\"addLegend\":true,\"legendPosition\":\"right\",\"isDonut\":true,\"labels\":{\"show\":true,\"values\":true,\"last_level\":true,\"truncate\":100}}}","kibanaSavedObjectMeta":{"searchSourceJSON":"{\"index\":\"1ff23f8d-3efa-4f7d-8796-57a76c624160\",\"query\":{\"query\":\"event.type:*\",\"language\":\"kuery\"},\"filter\":[]}"},"description":"Répartition par type d'événement de sécurité"},"references":[{"id":"1ff23f8d-3efa-4f7d-8796-57a76c624160","name":"kibanaSavedObjectMeta.searchSourceJSON.index","type":"index-pattern"}]}
{"type":"visualization","id":"sec-viz-severity","attributes":{"title":"[Security] Sévérité des événements","visState":"{\"title\":\"Sévérité\",\"type\":\"histogram\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"event.severity\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":5},\"schema\":\"segment\"},{\"id\":\"3\",\"enabled\":true,\"type\":\"date_histogram\",\"params\":{\"field\":\"@timestamp\",\"useNormalizedEsInterval\":true,\"interval\":\"1d\",\"min_doc_count\":1},\"schema\":\"group\"}],\"params\":{\"type\":\"histogram\",\"addTooltip\":true,\"addLegend\":true,\"legendPosition\":\"top\"}}","kibanaSavedObjectMeta":{"searchSourceJSON":"{\"index\":\"1ff23f8d-3efa-4f7d-8796-57a76c624160\",\"query\":{\"query\":\"event.severity:*\",\"language\":\"kuery\"},\"filter\":[]}"},"description":"Distribution de la sévérité dans le temps"},"references":[{"id":"1ff23f8d-3efa-4f7d-8796-57a76c624160","name":"kibanaSavedObjectMeta.searchSourceJSON.index","type":"index-pattern"}]}
{"type":"visualization","id":"sec-viz-fail2ban-jails","attributes":{"title":"[Security] Fail2ban - Bans par jail","visState":"{\"title\":\"Fail2ban Bans par jail\",\"type\":\"histogram\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"jail\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":10},\"schema\":\"segment\"},{\"id\":\"3\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"event.type\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":5},\"schema\":\"group\"}],\"params\":{\"type\":\"histogram\",\"addTooltip\":true,\"addLegend\":true,\"legendPosition\":\"top\"}}","kibanaSavedObjectMeta":{"searchSourceJSON":"{\"index\":\"1ff23f8d-3efa-4f7d-8796-57a76c624160\",\"query\":{\"query\":\"log_type:fail2ban\",\"language\":\"kuery\"},\"filter\":[]}"},"description":"Bans et unbans par jail fail2ban"},"references":[{"id":"1ff23f8d-3efa-4f7d-8796-57a76c624160","name":"kibanaSavedObjectMeta.searchSourceJSON.index","type":"index-pattern"}]}
{"type":"visualization","id":"sec-viz-asterisk-events","attributes":{"title":"[Security] Asterisk - Événements sécurité","visState":"{\"title\":\"Asterisk Security Events\",\"type\":\"histogram\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"date_histogram\",\"params\":{\"field\":\"@timestamp\",\"useNormalizedEsInterval\":true,\"interval\":\"1h\",\"min_doc_count\":1},\"schema\":\"segment\"},{\"id\":\"3\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"security_event\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":5},\"schema\":\"group\"}],\"params\":{\"type\":\"histogram\",\"addTooltip\":true,\"addLegend\":true,\"legendPosition\":\"top\"}}","kibanaSavedObjectMeta":{"searchSourceJSON":"{\"index\":\"1ff23f8d-3efa-4f7d-8796-57a76c624160\",\"query\":{\"query\":\"log_type:asterisk\",\"language\":\"kuery\"},\"filter\":[]}"},"description":"Événements de sécurité Asterisk par heure"},"references":[{"id":"1ff23f8d-3efa-4f7d-8796-57a76c624160","name":"kibanaSavedObjectMeta.searchSourceJSON.index","type":"index-pattern"}]}
{"type":"visualization","id":"sec-viz-ssh-auth","attributes":{"title":"[Security] SSH - Authentifications","visState":"{\"title\":\"SSH Authentifications\",\"type\":\"histogram\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"date_histogram\",\"params\":{\"field\":\"@timestamp\",\"useNormalizedEsInterval\":true,\"interval\":\"1h\",\"min_doc_count\":1},\"schema\":\"segment\"},{\"id\":\"3\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"event.type\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":5},\"schema\":\"group\"}],\"params\":{\"type\":\"histogram\",\"addTooltip\":true,\"addLegend\":true,\"legendPosition\":\"top\"}}","kibanaSavedObjectMeta":{"searchSourceJSON":"{\"index\":\"1ff23f8d-3efa-4f7d-8796-57a76c624160\",\"query\":{\"query\":\"log_type:auth\",\"language\":\"kuery\"},\"filter\":[]}"},"description":"Tentatives SSH réussies vs échouées par heure"},"references":[{"id":"1ff23f8d-3efa-4f7d-8796-57a76c624160","name":"kibanaSavedObjectMeta.searchSourceJSON.index","type":"index-pattern"}]}
{"type":"visualization","id":"sec-viz-top-usernames","attributes":{"title":"[Security] Top usernames ciblés","visState":"{\"title\":\"Top usernames ciblés\",\"type\":\"tagcloud\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"username\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":30},\"schema\":\"segment\"}],\"params\":{\"scale\":\"linear\",\"orientation\":\"single\",\"minFontSize\":14,\"maxFontSize\":72,\"showLabel\":true}}","kibanaSavedObjectMeta":{"searchSourceJSON":"{\"index\":\"1ff23f8d-3efa-4f7d-8796-57a76c624160\",\"query\":{\"query\":\"username:*\",\"language\":\"kuery\"},\"filter\":[]}"},"description":"Nuage de mots des usernames les plus ciblés"},"references":[{"id":"1ff23f8d-3efa-4f7d-8796-57a76c624160","name":"kibanaSavedObjectMeta.searchSourceJSON.index","type":"index-pattern"}]}
{"type":"visualization","id":"sec-viz-asn-providers","attributes":{"title":"[Security] Top ASN / Providers","visState":"{\"title\":\"Top ASN Providers\",\"type\":\"table\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"geoip_asn.organization_name\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":15},\"schema\":\"bucket\"},{\"id\":\"3\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"geoip.country_name\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":1},\"schema\":\"bucket\"}],\"params\":{\"perPage\":15,\"showPartialRows\":false,\"showTotal\":true,\"totalFunc\":\"sum\"}}","kibanaSavedObjectMeta":{"searchSourceJSON":"{\"index\":\"1ff23f8d-3efa-4f7d-8796-57a76c624160\",\"query\":{\"query\":\"geoip_asn.organization_name:*\",\"language\":\"kuery\"},\"filter\":[]}"},"description":"Providers réseau sources d'attaques"},"references":[{"id":"1ff23f8d-3efa-4f7d-8796-57a76c624160","name":"kibanaSavedObjectMeta.searchSourceJSON.index","type":"index-pattern"}]}
{"type":"visualization","id":"sec-viz-metrics-count","attributes":{"title":"[Security] Métriques clés","visState":"{\"title\":\"Métriques clés\",\"type\":\"metric\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{\"customLabel\":\"Total événements\"},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"cardinality\",\"params\":{\"field\":\"attacker_ip\",\"customLabel\":\"IPs uniques\"},\"schema\":\"metric\"},{\"id\":\"3\",\"enabled\":true,\"type\":\"cardinality\",\"params\":{\"field\":\"geoip.country_iso_code\",\"customLabel\":\"Pays sources\"},\"schema\":\"metric\"}],\"params\":{\"addTooltip\":true,\"addLegend\":false,\"type\":\"metric\",\"metric\":{\"percentageMode\":false,\"colorSchema\":\"Green to Red\",\"useRanges\":false,\"style\":{\"bgColor\":false,\"fontSize\":60}}}}","kibanaSavedObjectMeta":{"searchSourceJSON":"{\"index\":\"1ff23f8d-3efa-4f7d-8796-57a76c624160\",\"query\":{\"query\":\"event.category:security\",\"language\":\"kuery\"},\"filter\":[]}"},"description":"Compteurs clés: total événements, IPs uniques, pays"},"references":[{"id":"1ff23f8d-3efa-4f7d-8796-57a76c624160","name":"kibanaSavedObjectMeta.searchSourceJSON.index","type":"index-pattern"}]}
{"type":"dashboard","id":"sec-dashboard-overview","attributes":{"title":"[Security] Vue d'ensemble - Attaques","description":"Dashboard principal de sécurité - fail2ban, Asterisk, SSH","timeRestore":true,"timeTo":"now","timeFrom":"now-7d","refreshInterval":{"pause":false,"value":60000},"kibanaSavedObjectMeta":{"searchSourceJSON":"{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[]}"},"panelsJSON":"[{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":0,\"y\":0,\"w\":48,\"h\":6,\"i\":\"1\"},\"panelIndex\":\"1\",\"embeddableConfig\":{},\"panelRefName\":\"panel_1\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":0,\"y\":6,\"w\":48,\"h\":12,\"i\":\"2\"},\"panelIndex\":\"2\",\"embeddableConfig\":{},\"panelRefName\":\"panel_2\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":0,\"y\":18,\"w\":24,\"h\":15,\"i\":\"3\"},\"panelIndex\":\"3\",\"embeddableConfig\":{},\"panelRefName\":\"panel_3\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":24,\"y\":18,\"w\":24,\"h\":15,\"i\":\"4\"},\"panelIndex\":\"4\",\"embeddableConfig\":{},\"panelRefName\":\"panel_4\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":0,\"y\":33,\"w\":24,\"h\":12,\"i\":\"5\"},\"panelIndex\":\"5\",\"embeddableConfig\":{},\"panelRefName\":\"panel_5\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":24,\"y\":33,\"w\":24,\"h\":12,\"i\":\"6\"},\"panelIndex\":\"6\",\"embeddableConfig\":{},\"panelRefName\":\"panel_6\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":0,\"y\":45,\"w\":24,\"h\":12,\"i\":\"7\"},\"panelIndex\":\"7\",\"embeddableConfig\":{},\"panelRefName\":\"panel_7\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":24,\"y\":45,\"w\":24,\"h\":12,\"i\":\"8\"},\"panelIndex\":\"8\",\"embeddableConfig\":{},\"panelRefName\":\"panel_8\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":0,\"y\":57,\"w\":24,\"h\":12,\"i\":\"9\"},\"panelIndex\":\"9\",\"embeddableConfig\":{},\"panelRefName\":\"panel_9\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":24,\"y\":57,\"w\":24,\"h\":12,\"i\":\"10\"},\"panelIndex\":\"10\",\"embeddableConfig\":{},\"panelRefName\":\"panel_10\"}]","optionsJSON":"{\"useMargins\":true,\"syncColors\":true,\"syncCursor\":true,\"syncTooltips\":false,\"hidePanelTitles\":false}"},"references":[{"name":"panel_1","type":"visualization","id":"sec-viz-metrics-count"},{"name":"panel_2","type":"visualization","id":"sec-viz-attacks-timeline"},{"name":"panel_3","type":"visualization","id":"sec-viz-top-attackers"},{"name":"panel_4","type":"visualization","id":"sec-viz-geo-map"},{"name":"panel_5","type":"visualization","id":"sec-viz-attack-types"},{"name":"panel_6","type":"visualization","id":"sec-viz-severity"},{"name":"panel_7","type":"visualization","id":"sec-viz-fail2ban-jails"},{"name":"panel_8","type":"visualization","id":"sec-viz-asterisk-events"},{"name":"panel_9","type":"visualization","id":"sec-viz-ssh-auth"},{"name":"panel_10","type":"visualization","id":"sec-viz-asn-providers"}]}
{"type":"dashboard","id":"sec-dashboard-fail2ban","attributes":{"title":"[Security] Fail2ban - Détail","description":"Dashboard détaillé fail2ban - bans, unbans, jails, IPs","timeRestore":true,"timeTo":"now","timeFrom":"now-7d","refreshInterval":{"pause":false,"value":60000},"kibanaSavedObjectMeta":{"searchSourceJSON":"{\"query\":{\"query\":\"log_type:fail2ban\",\"language\":\"kuery\"},\"filter\":[]}"},"panelsJSON":"[{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":0,\"y\":0,\"w\":48,\"h\":12,\"i\":\"1\"},\"panelIndex\":\"1\",\"embeddableConfig\":{},\"panelRefName\":\"panel_1\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":0,\"y\":12,\"w\":24,\"h\":12,\"i\":\"2\"},\"panelIndex\":\"2\",\"embeddableConfig\":{},\"panelRefName\":\"panel_2\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":24,\"y\":12,\"w\":24,\"h\":12,\"i\":\"3\"},\"panelIndex\":\"3\",\"embeddableConfig\":{},\"panelRefName\":\"panel_3\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":0,\"y\":24,\"w\":24,\"h\":12,\"i\":\"4\"},\"panelIndex\":\"4\",\"embeddableConfig\":{},\"panelRefName\":\"panel_4\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":24,\"y\":24,\"w\":24,\"h\":12,\"i\":\"5\"},\"panelIndex\":\"5\",\"embeddableConfig\":{},\"panelRefName\":\"panel_5\"}]","optionsJSON":"{\"useMargins\":true,\"syncColors\":true,\"syncCursor\":true,\"hidePanelTitles\":false}"},"references":[{"name":"panel_1","type":"visualization","id":"sec-viz-fail2ban-jails"},{"name":"panel_2","type":"visualization","id":"sec-viz-top-attackers"},{"name":"panel_3","type":"visualization","id":"sec-viz-geo-map"},{"name":"panel_4","type":"visualization","id":"sec-viz-attack-types"},{"name":"panel_5","type":"visualization","id":"sec-viz-asn-providers"}]}
{"type":"dashboard","id":"sec-dashboard-asterisk","attributes":{"title":"[Security] Asterisk - Détail","description":"Dashboard détaillé Asterisk - tentatives SIP, brute force","timeRestore":true,"timeTo":"now","timeFrom":"now-7d","refreshInterval":{"pause":false,"value":60000},"kibanaSavedObjectMeta":{"searchSourceJSON":"{\"query\":{\"query\":\"log_type:asterisk\",\"language\":\"kuery\"},\"filter\":[]}"},"panelsJSON":"[{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":0,\"y\":0,\"w\":48,\"h\":12,\"i\":\"1\"},\"panelIndex\":\"1\",\"embeddableConfig\":{},\"panelRefName\":\"panel_1\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":0,\"y\":12,\"w\":24,\"h\":12,\"i\":\"2\"},\"panelIndex\":\"2\",\"embeddableConfig\":{},\"panelRefName\":\"panel_2\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":24,\"y\":12,\"w\":24,\"h\":12,\"i\":\"3\"},\"panelIndex\":\"3\",\"embeddableConfig\":{},\"panelRefName\":\"panel_3\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":0,\"y\":24,\"w\":24,\"h\":12,\"i\":\"4\"},\"panelIndex\":\"4\",\"embeddableConfig\":{},\"panelRefName\":\"panel_4\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":24,\"y\":24,\"w\":24,\"h\":12,\"i\":\"5\"},\"panelIndex\":\"5\",\"embeddableConfig\":{},\"panelRefName\":\"panel_5\"}]","optionsJSON":"{\"useMargins\":true,\"syncColors\":true,\"syncCursor\":true,\"hidePanelTitles\":false}"},"references":[{"name":"panel_1","type":"visualization","id":"sec-viz-asterisk-events"},{"name":"panel_2","type":"visualization","id":"sec-viz-top-attackers"},{"name":"panel_3","type":"visualization","id":"sec-viz-geo-map"},{"name":"panel_4","type":"visualization","id":"sec-viz-top-usernames"},{"name":"panel_5","type":"visualization","id":"sec-viz-asn-providers"}]}
{"type":"dashboard","id":"sec-dashboard-ssh","attributes":{"title":"[Security] SSH/Auth - Détail","description":"Dashboard détaillé SSH - authentifications, sudo, brute force","timeRestore":true,"timeTo":"now","timeFrom":"now-7d","refreshInterval":{"pause":false,"value":60000},"kibanaSavedObjectMeta":{"searchSourceJSON":"{\"query\":{\"query\":\"log_type:auth\",\"language\":\"kuery\"},\"filter\":[]}"},"panelsJSON":"[{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":0,\"y\":0,\"w\":48,\"h\":12,\"i\":\"1\"},\"panelIndex\":\"1\",\"embeddableConfig\":{},\"panelRefName\":\"panel_1\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":0,\"y\":12,\"w\":24,\"h\":12,\"i\":\"2\"},\"panelIndex\":\"2\",\"embeddableConfig\":{},\"panelRefName\":\"panel_2\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":24,\"y\":12,\"w\":24,\"h\":12,\"i\":\"3\"},\"panelIndex\":\"3\",\"embeddableConfig\":{},\"panelRefName\":\"panel_3\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":0,\"y\":24,\"w\":24,\"h\":12,\"i\":\"4\"},\"panelIndex\":\"4\",\"embeddableConfig\":{},\"panelRefName\":\"panel_4\"},{\"version\":\"8.x\",\"type\":\"visualization\",\"gridData\":{\"x\":24,\"y\":24,\"w\":24,\"h\":12,\"i\":\"5\"},\"panelIndex\":\"5\",\"embeddableConfig\":{},\"panelRefName\":\"panel_5\"}]","optionsJSON":"{\"useMargins\":true,\"syncColors\":true,\"syncCursor\":true,\"hidePanelTitles\":false}"},"references":[{"name":"panel_1","type":"visualization","id":"sec-viz-ssh-auth"},{"name":"panel_2","type":"visualization","id":"sec-viz-top-attackers"},{"name":"panel_3","type":"visualization","id":"sec-viz-geo-map"},{"name":"panel_4","type":"visualization","id":"sec-viz-top-usernames"},{"name":"panel_5","type":"visualization","id":"sec-viz-asn-providers"}]}
ENDNDJSON
)

# Écrire le NDJSON dans un fichier temporaire pour éviter les problèmes d'échappement
TMPFILE=$(mktemp /tmp/kibana-dashboards-XXXXXX.ndjson)
echo "$NDJSON_PAYLOAD" > "$TMPFILE"

RESPONSE=$(curl -k -s -w "\n%{http_code}" \
  -u "$ES_USER:$ES_PASS" \
  -H "kbn-xsrf: true" \
  -X POST "${KIBANA}/api/saved_objects/_import?overwrite=true" \
  --form file=@"$TMPFILE")

rm -f "$TMPFILE"

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    SUCCESS=$(echo "$BODY" | jq -r '.successCount // 0' 2>/dev/null)
    ERRORS=$(echo "$BODY" | jq -r '.errors | length // 0' 2>/dev/null)
    echo "  ✅ Import terminé: ${SUCCESS} objets importés"
    if [ "$ERRORS" != "0" ] && [ "$ERRORS" != "null" ]; then
        echo "  ⚠️  ${ERRORS} erreurs:"
        echo "$BODY" | jq -r '.errors[]? | "    - \(.id): \(.error.message // .error.type)"' 2>/dev/null
    fi
else
    echo "  ❌ Erreur HTTP ${HTTP_CODE}:"
    echo "$BODY" | jq -r '.message // .' 2>/dev/null || echo "$BODY"
fi
echo ""

#========================= VERIFICATION ========================================

echo "🔍 Vérification dashboards créés..."
echo ""

curl -k -s -u "$ES_USER:$ES_PASS" \
  -H "kbn-xsrf: true" \
  "${KIBANA}/api/saved_objects/_find?type=dashboard&search=Security" | \
  jq -r '.saved_objects[]? | "  ✅ \(.attributes.title) (id: \(.id))"' 2>/dev/null

echo ""
echo "✅ Dashboards créés!"
echo ""
echo "📋 Accès:"
echo "  Vue d'ensemble:  ${KIBANA}/app/dashboards#/view/sec-dashboard-overview"
echo "  Fail2ban:        ${KIBANA}/app/dashboards#/view/sec-dashboard-fail2ban"
echo "  Asterisk:        ${KIBANA}/app/dashboards#/view/sec-dashboard-asterisk"
echo "  SSH/Auth:        ${KIBANA}/app/dashboards#/view/sec-dashboard-ssh"
echo ""
