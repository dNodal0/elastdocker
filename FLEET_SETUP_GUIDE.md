# Configuration Fleet Server dans Kibana - Guide Étape par Étape

## 📋 Informations nécessaires
- **Fleet Server URL publique** : https://90.127.121.214:8220
- **Agent Policy Name** : Security Logs - Remote Clients
- **Namespace** : security

## 🚀 Étapes de configuration

### 1️⃣ Accéder à Fleet Settings
```
Kibana → Menu (☰) → Management → Fleet
```

### 2️⃣ Configurer Fleet Server (premier accès)

Si Fleet demande une configuration initiale :
- Cliquer sur **"Add Fleet Server"**
- **Fleet Server host** : `https://90.127.121.214:8220`
- **Name** : `Fleet Server ElasticDocker`
- Cliquer **"Generate Fleet Server policy"** (auto)
- Notre conteneur Fleet Server est déjà démarré, donc cliquer **"Continue"**

### 3️⃣ Aller dans Settings (si déjà configuré)
```
Fleet → Settings (onglet en haut)
```

Vérifier/Ajouter :
- **Fleet Server hosts** : https://90.127.121.214:8220
- **Elasticsearch hosts** : https://elasticsearch:9200 (ou l'IP interne si nécessaire)

### 4️⃣ Créer la nouvelle Agent Policy

```
Fleet → Agent Policies → Create agent policy
```

**Paramètres** :
- **Name** : `Security Logs - Remote Clients`
- **Description** : `Monitor security logs (auth.log, syslog, fail2ban) from remote Linux clients`
- **Namespace** : `security`
- **Advanced options** :
  - ✅ Collect system logs and metrics
  - ✅ Collect agent logs
  - ✅ Collect agent metrics

Cliquer **"Create agent policy"**

### 5️⃣ Ajouter l'intégration System

Dans la policy nouvellement créée :
```
Security Logs - Remote Clients → Add integration → Search "System"
```

**Configuration System Integration** :
- **Integration name** : `system-security-logs`
- **Logs** :
  - ✅ **System logs** (syslog) - Enable
    - Paths : `/var/log/syslog`, `/var/log/messages`
  - ✅ **Auth logs** - Enable
    - Paths : `/var/log/auth.log`, `/var/log/secure`
- **Metrics** : (optionnel, peut désactiver pour économiser ressources)

Cliquer **"Save and continue"** → **"Add Elastic Agent to your hosts"**

### 6️⃣ Générer Enrollment Token

Vous verrez un écran avec :
- **Enrollment token** (copier ce token !)
- **Installation command** pour Linux

**Exemple de token** : 
```
AAABBBCCCDDD123456789...
```

⚠️ **IMPORTANT** : Copier ce token, il sera nécessaire pour l'installation sur nuc !

---

## 📝 Commande d'installation sur NUC

Une fois le token généré, sur le serveur **nuc** :

```bash
# Télécharger Elastic Agent 9.2.3
curl -L -O https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-9.2.3-linux-x86_64.tar.gz

# Extraire
tar xzvf elastic-agent-9.2.3-linux-x86_64.tar.gz
cd elastic-agent-9.2.3-linux-x86_64

# Installer avec enrollment (remplacer <TOKEN> par le vrai token)
sudo ./elastic-agent install \
  --url=https://90.127.121.214:8220 \
  --enrollment-token=<TOKEN> \
  --insecure

# L'option --insecure accepte le certificat auto-signé
```

---

## ✅ Vérification

Retourner dans **Kibana → Fleet → Agents**
- Vous devriez voir l'agent `nuc` avec status **Healthy**
- Les logs arriveront dans l'index `logs-system.auth-*` et `logs-system.syslog-*`

Pour voir les logs :
```
Kibana → Discover → Créer Data View : logs-system.*
```

