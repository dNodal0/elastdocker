#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Setup Fleet Policies - Elastic Kibana API
# Crée/modifie les agent policies et package policies via Fleet API
###############################################################################

KIBANA_URL="https://kibana.elastic.local"
KIBANA_USER="${ELASTIC_USERNAME:-elastic}"
KIBANA_PASS="${ELASTIC_PASSWORD:?Variable ELASTIC_PASSWORD requise}"
CURL_OPTS=(-sk -u "${KIBANA_USER}:${KIBANA_PASS}" -H "kbn-xsrf: true" -H "Content-Type: application/json")

API_POLICIES="${KIBANA_URL}/api/fleet/agent_policies"
API_PKG_POLICIES="${KIBANA_URL}/api/fleet/package_policies"
API_PACKAGES="${KIBANA_URL}/api/fleet/epm/packages"

log_ok()  { echo "  ✅ $*"; }
log_err() { echo "  ❌ $*"; }
log_step(){ echo -e "\n━━━ $* ━━━"; }

api_get()    { curl "${CURL_OPTS[@]}" -XGET  "$1" 2>/dev/null; }
api_post()   { curl "${CURL_OPTS[@]}" -XPOST "$1" -d "$2" 2>/dev/null; }
api_put()    { curl "${CURL_OPTS[@]}" -XPUT  "$1" -d "$2" 2>/dev/null; }

get_policy_id() {
  api_get "$API_POLICIES" | jq -r --arg n "$1" '.items[] | select(.name==$n) | .id // empty'
}

get_pkg_policy_id_by_name() {
  local policy_id="$1" pkg_name="$2"
  api_get "${API_PKG_POLICIES}?perPage=1000" \
    | jq -r --arg pid "$policy_id" --arg n "$pkg_name" \
      '.items[] | select(.policy_id==$pid and .name==$n) | .id // empty'
}

get_latest_pkg_version() {
  api_get "${API_PACKAGES}?category=&prerelease=false" \
    | jq -r --arg p "$1" '[.items[] | select(.name==$p)] | sort_by(.version) | last | .version // empty'
}

check_result() {
  local resp="$1" label="$2"
  if echo "$resp" | jq -e '.item.id' &>/dev/null; then
    log_ok "${label} (ID: $(echo "$resp" | jq -r '.item.id'))"
    return 0
  else
    log_err "${label}: $(echo "$resp" | jq -r '.message // .')"
    return 1
  fi
}

###############################################################################
# ÉTAPE 1 : Supprimer "Agent policy 1"
###############################################################################
log_step "ÉTAPE 1 : Supprimer 'Agent policy 1'"

POLICY1_ID=$(get_policy_id "Agent policy 1")
if [[ -n "$POLICY1_ID" ]]; then
  RESP=$(api_post "${API_POLICIES}/delete" "{\"agentPolicyId\":\"${POLICY1_ID}\"}")
  if echo "$RESP" | jq -e '.id' &>/dev/null; then
    log_ok "Policy supprimée (ID: ${POLICY1_ID})"
  else
    log_err "Échec suppression: $(echo "$RESP" | jq -r '.message // .')"
  fi
else
  log_ok "Policy 'Agent policy 1' inexistante, rien à supprimer"
fi

###############################################################################
# ÉTAPE 2 : Fixer policy "Security Logs - Remote Clients"
###############################################################################
log_step "ÉTAPE 2 : Fixer 'Security Logs - Remote Clients'"

REMOTE_POLICY_ID=$(get_policy_id "Security Logs - Remote Clients")
if [[ -z "$REMOTE_POLICY_ID" ]]; then
  log_err "Policy 'Security Logs - Remote Clients' introuvable"
else
  log_ok "Policy trouvée (ID: ${REMOTE_POLICY_ID})"

  # 2a. Renommer system-1 → System-Auth-Logs-Remote + namespace security
  SYS1_ID=$(get_pkg_policy_id_by_name "$REMOTE_POLICY_ID" "system-1")
  if [[ -n "$SYS1_ID" ]]; then
    SYS1_FULL=$(api_get "${API_PKG_POLICIES}/${SYS1_ID}" | jq '.item')
    UPDATED=$(echo "$SYS1_FULL" | jq '
      .name = "System-Auth-Logs-Remote"
      | .namespace = "security"
      | del(.revision, .created_at, .created_by, .updated_at, .updated_by, .id, .version, .agents, .elasticsearch, .spaceIds)
    ')
    RESP=$(api_put "${API_PKG_POLICIES}/${SYS1_ID}" "$UPDATED")
    check_result "$RESP" "Rename system-1 → System-Auth-Logs-Remote" || true
  else
    # Peut-être déjà renommé
    EXISTING=$(get_pkg_policy_id_by_name "$REMOTE_POLICY_ID" "System-Auth-Logs-Remote")
    if [[ -n "$EXISTING" ]]; then
      log_ok "Integration déjà renommée System-Auth-Logs-Remote (ID: ${EXISTING})"
    else
      log_err "Integration 'system-1' introuvable dans la policy"
    fi
  fi

  # 2b. Ajouter Custom Logs filestream pour fail2ban
  EXISTING_F2B=$(get_pkg_policy_id_by_name "$REMOTE_POLICY_ID" "Fail2ban-Logs-Remote")
  if [[ -n "$EXISTING_F2B" ]]; then
    log_ok "Integration Fail2ban-Logs-Remote existe déjà (ID: ${EXISTING_F2B})"
  else
    RESP=$(api_post "$API_PKG_POLICIES" "$(jq -n --arg pid "$REMOTE_POLICY_ID" '{
      name: "Fail2ban-Logs-Remote",
      description: "Fail2ban log monitoring",
      namespace: "security",
      policy_id: $pid,
      package: { name: "filestream", title: "Custom Logs (Filestream)", version: "2.3.1" },
      inputs: [{
        type: "filestream",
        enabled: true,
        streams: [{
          enabled: true,
          data_stream: { type: "logs", dataset: "filestream.filestream",
            elasticsearch: { dynamic_dataset: true, dynamic_namespace: true }
          },
          vars: {
            paths: { value: ["/var/log/fail2ban.log"], type: "text" },
            "data_stream.dataset": { value: "fail2ban", type: "text" },
            pipeline: { value: "logs-fail2ban-security", type: "text" },
            tags: { value: ["security","fail2ban"], type: "text" }
          }
        }]
      }]
    }')")
    check_result "$RESP" "Création Fail2ban-Logs-Remote" || true
  fi
fi

###############################################################################
# ÉTAPE 3 : Créer policy "Security-Linux-LAN" + integrations
###############################################################################
log_step "ÉTAPE 3 : Créer 'Security-Linux-LAN'"

LINUX_LAN_ID=$(get_policy_id "Security-Linux-LAN")
if [[ -z "$LINUX_LAN_ID" ]]; then
  RESP=$(api_post "$API_POLICIES" '{"name":"Security-Linux-LAN","description":"Linux LAN security monitoring","namespace":"security","monitoring_enabled":["logs","metrics"]}')
  if echo "$RESP" | jq -e '.item.id' &>/dev/null; then
    LINUX_LAN_ID=$(echo "$RESP" | jq -r '.item.id')
    log_ok "Policy créée (ID: ${LINUX_LAN_ID})"
  else
    log_err "Échec création: $(echo "$RESP" | jq -r '.message // .')"
  fi
else
  log_ok "Policy existe déjà (ID: ${LINUX_LAN_ID})"
fi

if [[ -n "${LINUX_LAN_ID:-}" ]]; then
  # 3a. System integration (input type: logfile)
  EXISTING=$(get_pkg_policy_id_by_name "$LINUX_LAN_ID" "System-Auth-Logs-LAN")
  if [[ -n "$EXISTING" ]]; then
    log_ok "Integration System-Auth-Logs-LAN existe déjà (ID: ${EXISTING})"
  else
    RESP=$(api_post "$API_PKG_POLICIES" "$(jq -n --arg pid "$LINUX_LAN_ID" '{
      name: "System-Auth-Logs-LAN",
      description: "System auth and syslog",
      namespace: "security",
      policy_id: $pid,
      package: { name: "system", title: "System", version: "2.12.0" },
      inputs: [
        {
          type: "logfile",
          enabled: true,
          streams: [
            {
              enabled: true,
              data_stream: { type: "logs", dataset: "system.auth" },
              vars: {
                paths: { value: ["/var/log/auth.log*","/var/log/secure*"], type: "text" },
                preserve_original_event: { value: false, type: "bool" }
              }
            },
            {
              enabled: true,
              data_stream: { type: "logs", dataset: "system.syslog" },
              vars: {
                paths: { value: ["/var/log/messages*","/var/log/syslog*"], type: "text" },
                preserve_original_event: { value: false, type: "bool" }
              }
            }
          ]
        },
        { type: "journald", enabled: false, streams: [] },
        { type: "winlog", enabled: false, streams: [] },
        { type: "system/metrics", enabled: false, streams: [] }
      ]
    }')")
    check_result "$RESP" "Création System-Auth-Logs-LAN" || true
  fi

  # 3b. Fail2ban Custom Logs filestream
  EXISTING=$(get_pkg_policy_id_by_name "$LINUX_LAN_ID" "Fail2ban-Logs-LAN")
  if [[ -n "$EXISTING" ]]; then
    log_ok "Integration Fail2ban-Logs-LAN existe déjà (ID: ${EXISTING})"
  else
    RESP=$(api_post "$API_PKG_POLICIES" "$(jq -n --arg pid "$LINUX_LAN_ID" '{
      name: "Fail2ban-Logs-LAN",
      description: "Fail2ban log monitoring",
      namespace: "security",
      policy_id: $pid,
      package: { name: "filestream", title: "Custom Logs (Filestream)", version: "2.3.1" },
      inputs: [{
        type: "filestream",
        enabled: true,
        streams: [{
          enabled: true,
          data_stream: { type: "logs", dataset: "filestream.filestream",
            elasticsearch: { dynamic_dataset: true, dynamic_namespace: true }
          },
          vars: {
            paths: { value: ["/var/log/fail2ban.log"], type: "text" },
            "data_stream.dataset": { value: "fail2ban", type: "text" },
            pipeline: { value: "logs-fail2ban-security", type: "text" },
            tags: { value: ["security","fail2ban"], type: "text" }
          }
        }]
      }]
    }')")
    check_result "$RESP" "Création Fail2ban-Logs-LAN" || true
  fi
fi

###############################################################################
# ÉTAPE 4 : Créer policy "Security-Windows" + Windows integration
###############################################################################
log_step "ÉTAPE 4 : Créer 'Security-Windows'"

WIN_POLICY_ID=$(get_policy_id "Security-Windows")
if [[ -z "$WIN_POLICY_ID" ]]; then
  RESP=$(api_post "$API_POLICIES" '{"name":"Security-Windows","description":"Windows security monitoring","namespace":"security","monitoring_enabled":["logs","metrics"]}')
  if echo "$RESP" | jq -e '.item.id' &>/dev/null; then
    WIN_POLICY_ID=$(echo "$RESP" | jq -r '.item.id')
    log_ok "Policy créée (ID: ${WIN_POLICY_ID})"
  else
    log_err "Échec création: $(echo "$RESP" | jq -r '.message // .')"
  fi
else
  log_ok "Policy existe déjà (ID: ${WIN_POLICY_ID})"
fi

if [[ -n "${WIN_POLICY_ID:-}" ]]; then
  # Windows event logs via system package (winlog input)
  # system package has winlog input with datasets: system.security, system.system, system.application
  EXISTING=$(get_pkg_policy_id_by_name "$WIN_POLICY_ID" "Windows-Security-Logs")
  if [[ -n "$EXISTING" ]]; then
    log_ok "Integration Windows-Security-Logs existe déjà (ID: ${EXISTING})"
  else
    RESP=$(api_post "$API_PKG_POLICIES" "$(jq -n --arg pid "$WIN_POLICY_ID" '{
      name: "Windows-Security-Logs",
      description: "Windows Security, System and Application event logs",
      namespace: "security",
      policy_id: $pid,
      package: { name: "system", title: "System", version: "2.12.0" },
      inputs: [
        { type: "logfile", enabled: false, streams: [] },
        { type: "journald", enabled: false, streams: [] },
        {
          type: "winlog",
          enabled: true,
          streams: [
            {
              enabled: true,
              data_stream: { type: "logs", dataset: "system.security" },
              vars: { preserve_original_event: { value: false, type: "bool" }, custom: { value: "", type: "yaml" } }
            },
            {
              enabled: true,
              data_stream: { type: "logs", dataset: "system.application" },
              vars: { preserve_original_event: { value: false, type: "bool" }, custom: { value: "", type: "yaml" } }
            },
            {
              enabled: true,
              data_stream: { type: "logs", dataset: "system.system" },
              vars: { preserve_original_event: { value: false, type: "bool" }, custom: { value: "", type: "yaml" } }
            }
          ]
        },
        { type: "system/metrics", enabled: false, streams: [] }
      ]
    }')")
    check_result "$RESP" "Création Windows-Security-Logs" || true
  fi
fi

###############################################################################
# ÉTAPE 5 : Créer policy "Security-macOS" + integrations
###############################################################################
log_step "ÉTAPE 5 : Créer 'Security-macOS'"

MAC_POLICY_ID=$(get_policy_id "Security-macOS")
if [[ -z "$MAC_POLICY_ID" ]]; then
  RESP=$(api_post "$API_POLICIES" '{"name":"Security-macOS","description":"macOS security monitoring","namespace":"security","monitoring_enabled":["logs","metrics"]}')
  if echo "$RESP" | jq -e '.item.id' &>/dev/null; then
    MAC_POLICY_ID=$(echo "$RESP" | jq -r '.item.id')
    log_ok "Policy créée (ID: ${MAC_POLICY_ID})"
  else
    log_err "Échec création: $(echo "$RESP" | jq -r '.message // .')"
  fi
else
  log_ok "Policy existe déjà (ID: ${MAC_POLICY_ID})"
fi

if [[ -n "${MAC_POLICY_ID:-}" ]]; then
  # 5a. System integration (logfile input for macOS)
  EXISTING=$(get_pkg_policy_id_by_name "$MAC_POLICY_ID" "macOS-System-Logs")
  if [[ -n "$EXISTING" ]]; then
    log_ok "Integration macOS-System-Logs existe déjà (ID: ${EXISTING})"
  else
    RESP=$(api_post "$API_PKG_POLICIES" "$(jq -n --arg pid "$MAC_POLICY_ID" '{
      name: "macOS-System-Logs",
      description: "macOS system and auth logs",
      namespace: "security",
      policy_id: $pid,
      package: { name: "system", title: "System", version: "2.12.0" },
      inputs: [
        {
          type: "logfile",
          enabled: true,
          streams: [
            {
              enabled: true,
              data_stream: { type: "logs", dataset: "system.auth" },
              vars: {
                paths: { value: ["/var/log/auth.log*"], type: "text" },
                preserve_original_event: { value: false, type: "bool" }
              }
            },
            {
              enabled: true,
              data_stream: { type: "logs", dataset: "system.syslog" },
              vars: {
                paths: { value: ["/var/log/system.log*","/private/var/log/system.log*"], type: "text" },
                preserve_original_event: { value: false, type: "bool" }
              }
            }
          ]
        },
        { type: "journald", enabled: false, streams: [] },
        { type: "winlog", enabled: false, streams: [] },
        { type: "system/metrics", enabled: false, streams: [] }
      ]
    }')")
    check_result "$RESP" "Création macOS-System-Logs" || true
  fi

  # 5b. Custom Logs filestream pour auth macOS
  EXISTING=$(get_pkg_policy_id_by_name "$MAC_POLICY_ID" "macOS-Auth-Logs")
  if [[ -n "$EXISTING" ]]; then
    log_ok "Integration macOS-Auth-Logs existe déjà (ID: ${EXISTING})"
  else
    RESP=$(api_post "$API_PKG_POLICIES" "$(jq -n --arg pid "$MAC_POLICY_ID" '{
      name: "macOS-Auth-Logs",
      description: "macOS authentication custom logs",
      namespace: "security",
      policy_id: $pid,
      package: { name: "filestream", title: "Custom Logs (Filestream)", version: "2.3.1" },
      inputs: [{
        type: "filestream",
        enabled: true,
        streams: [{
          enabled: true,
          data_stream: { type: "logs", dataset: "filestream.filestream",
            elasticsearch: { dynamic_dataset: true, dynamic_namespace: true }
          },
          vars: {
            paths: { value: ["/var/log/auth.log","/private/var/log/system.log"], type: "text" },
            "data_stream.dataset": { value: "macos_auth", type: "text" },
            pipeline: { value: "logs-auth-security", type: "text" },
            tags: { value: ["security","macos","auth"], type: "text" }
          }
        }]
      }]
    }')")
    check_result "$RESP" "Création macOS-Auth-Logs" || true
  fi
fi

###############################################################################
# VÉRIFICATION FINALE
###############################################################################
log_step "VÉRIFICATION FINALE"

echo ""
echo "Agent Policies :"
api_get "$API_POLICIES" | jq -r '.items[] | "  • \(.name) (ID: \(.id), agents: \(.agents // 0))"'

echo ""
echo "Package Policies (namespace=security) :"
api_get "${API_PKG_POLICIES}?perPage=1000" | jq -r '
  .items[]
  | select(.namespace=="security")
  | "  • \(.name) [pkg: \(.package.name)] → policy: \(.policy_id) (ID: \(.id))"
'

echo ""
log_ok "Script terminé"
