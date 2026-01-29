# 🚀 Traefik Configuration pour ElasticDocker

## 📋 Vue d'ensemble

Configuration Traefik reverse proxy pour accéder à votre stack Elasticsearch via des URLs propres avec HTTPS.

### ✨ Fonctionnalités

- ✅ Reverse proxy moderne avec Traefik v3.0
- ✅ HTTPS avec certificats auto-signés existants
- ✅ Dashboard Traefik pour monitoring
- ✅ URLs propres pour chaque service
- ✅ Préparé pour migration Let's Encrypt (production)

### 🌐 URLs disponibles

Une fois configuré, accédez à vos services via :

| Service | URL | Port Direct | Description |
|---------|-----|-------------|-------------|
| **Elasticsearch** | https://elasticsearch.elastic.local | 9200 | API Elasticsearch |
| **Kibana** | https://kibana.elastic.local | 5601 | Interface Kibana |
| **Logstash** | https://logstash.elastic.local | 9600 | API Logstash |
| **APM Server** | https://apm.elastic.local | 8200 | APM Server |
| **Traefik Dashboard** | https://traefik.elastic.local | 8080 | Monitoring Traefik |

---

## 🔧 Installation

### Étape 1 : Configurer /etc/hosts

Ajoutez les domaines internes à votre fichier hosts :

```bash
sudo nano /etc/hosts
```

Ajoutez ces lignes (remplacez `127.0.0.1` par l'IP de votre serveur si distant) :

```
127.0.0.1 elasticsearch.elastic.local
127.0.0.1 kibana.elastic.local
127.0.0.1 logstash.elastic.local
127.0.0.1 apm.elastic.local
127.0.0.1 traefik.elastic.local
```

### Étape 2 : Démarrer le stack avec Traefik

#### Option A : Docker Compose multi-fichiers

```bash
# Arrêter le stack actuel
docker compose down

# Démarrer avec Traefik
docker compose -f docker-compose.yml -f docker-compose.traefik.yml up -d
```

#### Option B : Modifier le Makefile (recommandé)

Ajoutez au `Makefile` :

```makefile
# Start Elastic Stack with Traefik
elk-traefik: setup
	docker compose -f docker-compose.yml -f docker-compose.traefik.yml up -d --build

# Stop everything including Traefik
down-traefik:
	docker compose -f docker-compose.yml -f docker-compose.traefik.yml down
```

Puis utilisez :

```bash
make elk-traefik
```

### Étape 3 : Vérifier le déploiement

```bash
# Vérifier que tous les conteneurs sont UP
docker compose ps

# Vérifier les logs Traefik
docker logs elastic-traefik

# Tester les URLs
curl -k https://elasticsearch.elastic.local
curl -k https://kibana.elastic.local
curl -k https://traefik.elastic.local
```

---

## 🧪 Tests de connectivité

### Test Elasticsearch via Traefik

```bash
# Avec le nouveau mot de passe
curl -k -u elastic:t9U6nXEme6nJ0IbM1bG2D2uq2ToWnx5Hh3EQSaZxUrU= \
  https://elasticsearch.elastic.local/_cluster/health?pretty

# Réponse attendue
{
  "cluster_name" : "elastdocker-cluster",
  "status" : "yellow",
  ...
}
```

### Test Kibana via navigateur

1. Ouvrez : https://kibana.elastic.local
2. Acceptez le certificat auto-signé
3. Connectez-vous avec :
   - Username: `elastic`
   - Password: `t9U6nXEme6nJ0IbM1bG2D2uq2ToWnx5Hh3EQSaZxUrU=`

### Test Traefik Dashboard

1. Ouvrez : http://localhost:8080 ou https://traefik.elastic.local
2. Visualisez les routes HTTP/HTTPS configurées

---

## 📁 Structure des fichiers

```
elastdocker/
├── docker-compose.yml              # Configuration principale
├── docker-compose.traefik.yml      # Configuration Traefik
├── traefik/
│   └── config/
│       └── dynamic.yml             # Config TLS et certificats
├── secrets/
│   └── certs/
│       ├── ca/
│       │   └── ca.crt
│       ├── elasticsearch/
│       │   ├── elasticsearch.crt
│       │   └── elasticsearch.key
│       ├── kibana/
│       │   ├── kibana.crt
│       │   └── kibana.key
│       └── apm-server/
│           ├── apm-server.crt
│           └── apm-server.key
└── TRAEFIK_SETUP.md               # Ce fichier
```

---

## 🔒 Sécurité

### Certificats actuels : Auto-signés

- ✅ **Avantages** :
  - Gratuits et immédiats
  - Parfaits pour développement/staging
  - Chiffrement complet du trafic

- ⚠️ **Limitations** :
  - Navigateurs affichent un warning (cliquez "Avancé" → "Continuer")
  - Non reconnus par les clients externes

### Migration vers Let's Encrypt (Production)

Pour obtenir des certificats valides reconnus par tous les navigateurs :

1. **Prérequis** :
   - Nom de domaine public (ex: `elk.mondomaine.com`)
   - Port 80 et 443 accessibles depuis Internet
   - DNS configuré vers votre serveur

2. **Modifier `docker-compose.traefik.yml`** :

```yaml
# Remplacer les lignes TLS par :
- "--certificatesresolvers.letsencrypt.acme.email=votre@email.com"
- "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
- "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
```

3. **Ajouter aux labels de chaque service** :

```yaml
- "traefik.http.routers.elasticsearch.tls.certresolver=letsencrypt"
```

---

## 🎛️ Configuration Traefik

### Ports exposés

| Port | Service | Description |
|------|---------|-------------|
| 80 | HTTP | Redirection automatique vers HTTPS |
| 443 | HTTPS | Accès sécurisé aux services |
| 8080 | Dashboard | Interface Traefik (dev only) |

### Dashboard Traefik

**URL** : http://localhost:8080 ou https://traefik.elastic.local

**Fonctionnalités** :
- Vue des routes HTTP/HTTPS
- État des services backend
- Métriques en temps réel
- Logs d'accès

⚠️ **Production** : Désactiver `--api.insecure=true` et ajouter authentification :

```yaml
- "--api.dashboard=true"
- "--api.insecure=false"
# Ajouter middleware d'authentification
```

---

## 🔧 Personnalisation

### Changer les noms de domaine

Modifiez dans `docker-compose.traefik.yml` :

```yaml
# Exemple : passer de .elastic.local à .monentreprise.local
- "traefik.http.routers.elasticsearch.rule=Host(`es.monentreprise.local`)"
- "traefik.http.routers.kibana.rule=Host(`kibana.monentreprise.local`)"
```

N'oubliez pas de mettre à jour `/etc/hosts` en conséquence.

### Ajouter une authentification basique

Générer un mot de passe hashé :

```bash
# Installer htpasswd si nécessaire
sudo apt-get install apache2-utils

# Générer hash (utilisateur: admin)
htpasswd -nb admin monmotdepasse
# Résultat : admin:$apr1$xyz...
```

Ajouter aux labels Traefik :

```yaml
- "traefik.http.middlewares.auth.basicauth.users=admin:$$apr1$$xyz..."
- "traefik.http.routers.kibana.middlewares=auth"
```

---

## 🐛 Dépannage

### Erreur "Bad Gateway" (502)

```bash
# Vérifier que les services backend sont UP
docker compose ps

# Vérifier les logs Traefik
docker logs elastic-traefik

# Vérifier la connectivité réseau
docker network inspect elastic
```

### Certificat refusé par le navigateur

**Normal pour certificats auto-signés** :
1. Cliquez sur "Avancé" ou "Détails"
2. Cliquez sur "Continuer vers le site" ou "Accepter le risque"

**Ou importez le CA dans votre navigateur** :

```bash
# Copier le certificat CA
cp secrets/certs/ca/ca.crt ~/Bureau/elastic-ca.crt

# Firefox : Préférences → Vie privée → Certificats → Importer
# Chrome : Paramètres → Sécurité → Gérer certificats → Autorités → Importer
```

### Services non accessibles via Traefik

```bash
# Vérifier les labels Traefik
docker inspect elastic-elasticsearch-1 | grep -A 10 Labels

# Vérifier les routes Traefik
curl http://localhost:8080/api/http/routers

# Tester l'accès direct (sans Traefik)
curl -k https://localhost:9200
```

---

## 📊 Monitoring

### Logs d'accès Traefik

```bash
# Logs en temps réel
docker logs -f elastic-traefik

# Filtrer par service
docker logs elastic-traefik | grep elasticsearch
```

### Métriques (optionnel)

Pour activer Prometheus metrics :

```yaml
# Ajouter dans docker-compose.traefik.yml
- "--metrics.prometheus=true"
- "--metrics.prometheus.entrypoint=metrics"
- "--entrypoints.metrics.address=:8082"
```

---

## 🔄 Commandes utiles

```bash
# Redémarrer Traefik uniquement
docker restart elastic-traefik

# Voir la configuration dynamique chargée
docker exec elastic-traefik cat /etc/traefik/dynamic/dynamic.yml

# Vérifier les certificats montés
docker exec elastic-traefik ls -la /certs/

# Recharger la configuration sans redémarrage
# (Traefik watch automatiquement dynamic.yml)
touch traefik/config/dynamic.yml

# Arrêter tout le stack
make down-traefik
# ou
docker compose -f docker-compose.yml -f docker-compose.traefik.yml down
```

---

## 🚀 Migration production

Pour déployer en production avec Let's Encrypt :

1. **Domaine public configuré** : Vérifiez que DNS pointe vers votre serveur
2. **Ports ouverts** : 80 et 443 accessibles depuis Internet
3. **Email configuré** : Pour notifications Let's Encrypt
4. **Modifier Traefik config** : Activer ACME challenge
5. **Tester en staging** : Utilisez Let's Encrypt staging endpoint d'abord
6. **Désactiver API insecure** : Sécuriser le dashboard

**Documentation officielle** : https://doc.traefik.io/traefik/https/acme/

---

## 📚 Ressources

- **Traefik Documentation** : https://doc.traefik.io/traefik/
- **Elasticsearch Security** : https://www.elastic.co/guide/en/elasticsearch/reference/current/security-minimal-setup.html
- **Docker Compose** : https://docs.docker.com/compose/compose-file/

---

**Généré le** : 2026-01-28
**Version Traefik** : v3.0
**Version Elastic Stack** : 9.2.3

🤖 **Generated with [Claude Code](https://claude.com/claude-code)**

Co-Authored-By: Claude <noreply@anthropic.com>
