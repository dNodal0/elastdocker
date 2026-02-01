# 🛡️ Security Monitoring avec Elastic Agent

Configuration complète pour monitorer **Fail2ban**, **Asterisk** et **SSH** via Elastic Agent et Fleet.

---

## ✨ Différences vs Filebeat

| Feature | Elastic Agent | Filebeat |
|---------|---------------|----------|
| **Configuration** | UI Fleet ✅ | Fichiers YAML |
| **Gestion** | Centralisée ✅ | Manuelle |
| **Updates** | Auto ✅ | Manuelles |
| **Parsing** | Ingest Pipelines | Logstash |
| **Monitoring** | Intégré ✅ | Séparé |
| **Scalabilité** | Excellente ✅ | Bonne |

---

## 🎯 Ce Que Ça Fait

### 3 Ingest Pipelines
1. **logs-fail2ban-security** - Parse bans + GeoIP
2. **logs-asterisk-security** - Parse SIP attacks + GeoIP
3. **logs-auth-security** - Parse SSH failures + GeoIP

### Données Collectées
- ✅ **Fail2ban**: Bans/Unbans, jail, IP, pays
- ✅ **Asterisk**: Tentatives SIP, extensions, IP, pays
- ✅ **SSH/Auth**: Échecs/Succès, user, IP, pays, sudo

### Enrichissement Automatique
- ✅ GeoIP (pays, ville, coordonnées GPS)
- ✅ ASN (fournisseur, datacenter)
- ✅ Event classification (type, category, severity)

---

## 🚀 Installation Rapide (20 min)

### Prérequis
- Cluster ELK 8.10+ avec Fleet Server configuré
- Elastic Agent sur NUC1 & NUC2
- Permissions lecture sur logs (fail2ban, asterisk, auth)

### Étape 1: Créer Pipelines

```bash
export ELASTIC_PASSWORD="ton_password"
./scripts/create-ingest-pipelines.sh
```

### Étape 2: Configurer Fleet

**Voir guide détaillé:** [QUICK_START.md](QUICK_START.md)

Résumé:
1. Créer policy "Security-Monitoring-NUCs"
2. Add integration "Custom Logs" (fail2ban) avec pipeline
3. Add integration "Custom Logs" (asterisk) avec pipeline
4. Add integration "System" (auth) avec pipeline

### Étape 3: Installer Agents

```bash
# Sur NUC1 & NUC2
curl -L -O https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-8.10.2-linux-x86_64.tar.gz
tar xzvf elastic-agent-8.10.2-linux-x86_64.tar.gz
cd elastic-agent-8.10.2-linux-x86_64

sudo ./elastic-agent install \
  --url=https://fleet-server:8220 \
  --enrollment-token=TOKEN_FROM_FLEET
```

### Étape 4: Vérifier

```bash
# Dans Kibana Discover
Index pattern: logs-*-security*
Query: event.type:*
```

---

## 📁 Contenu

```
elastic-agent-setup/
├── README.md                          # Ce fichier
├── QUICK_START.md                     # Guide 20 min
├── ELASTIC_AGENT_GUIDE.md             # Guide complet détaillé
│
└── scripts/
    └── create-ingest-pipelines.sh     # Créer 3 pipelines
```

---

## 🔍 Queries Essentielles

```lucene
# Tous les événements sécurité
event.type:(banned OR asterisk_attack_attempt OR ssh_failed_auth)

# Bans fail2ban
data_stream.dataset:fail2ban AND action:ban

# Attaques Asterisk SIP
data_stream.dataset:asterisk AND event.type:asterisk_attack_attempt

# Échecs SSH
event.type:ssh_failed_auth

# Top attaquants
attacker_ip:* | top attacker_ip

# Par pays
geoip.country_name:*

# Par NUC
host.name:"nuc1" OR host.name:"nuc2"
```

---

## 📊 Dashboards Recommandés

### Dashboard 1: Vue Globale Sécurité
- Timeline attaques par type
- Top 20 IPs avec pays
- Carte géographique
- Répartition événements
- Stats par NUC

### Dashboard 2: Fail2ban Détaillé
- Timeline bans par jail
- Top jails actives
- Table détaillée bans
- IPs récidivistes

### Dashboard 3: Asterisk SIP Scanner
- Timeline tentatives SIP par IP
- Map attaques VoIP
- Top scanner IPs
- Extensions ciblées

---

## 🛠️ Troubleshooting

### Logs ne remontent pas

```bash
# Vérifier agent
sudo elastic-agent status

# Logs agent
sudo tail -f /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson

# Vérifier permissions
sudo chmod +r /var/log/fail2ban.log
sudo usermod -a -G asterisk elastic-agent
```

### Pipeline ne parse pas

```bash
# Tester dans Kibana Dev Tools
POST _ingest/pipeline/logs-fail2ban-security/_simulate
{
  "docs": [
    {
      "_source": {
        "message": "2025-01-31 10:15:23 fail2ban.actions: NOTICE [sshd] Ban 1.2.3.4"
      }
    }
  ]
}
```

### GeoIP manquant

```bash
# Vérifier GeoIP
GET _ingest/geoip/stats

# Devrait avoir GeoLite2-City.mmdb et GeoLite2-ASN.mmdb
```

---

## 📈 Métriques Attendues

| Métrique | Valeur |
|----------|--------|
| **Latency** | <3 secondes (log → ES) |
| **Throughput** | ~10k events/sec |
| **Storage** | ~500 MB/jour (2 NUCs) |
| **Parsing success** | >95% |

---

## 🔐 Sécurité

### Checklist
- [ ] Fleet Server SSL/TLS activé
- [ ] Agents authentifiés via enrollment token
- [ ] Permissions logs minimales (lecture seule)
- [ ] GeoIP databases à jour
- [ ] Monitoring agents activé
- [ ] Alerting configuré

---

## 🎯 Prochaines Étapes

### Court Terme
1. ✅ Créer dashboards dans Kibana
2. ✅ Configurer alertes (email/Slack)
3. ✅ Ajuster seuils fail2ban

### Moyen Terme
1. Ajouter sources logs (nginx, postfix)
2. ML anomaly detection
3. Threat intelligence feeds
4. Rapport hebdomadaire auto

---

## 📚 Documentation

### Guides Inclus
- 📖 [QUICK_START.md](QUICK_START.md) - Installation 20 min
- 📖 [ELASTIC_AGENT_GUIDE.md](ELASTIC_AGENT_GUIDE.md) - Guide complet

### Ressources Externes
- [Elastic Agent Docs](https://www.elastic.co/guide/en/fleet/current/index.html)
- [Fleet Management](https://www.elastic.co/guide/en/fleet/current/fleet-overview.html)
- [Ingest Pipelines](https://www.elastic.co/guide/en/elasticsearch/reference/current/ingest.html)
- [Custom Logs Integration](https://www.elastic.co/guide/en/integrations/current/log.html)

---

## 🤝 Contribution

Des questions ou améliorations ? Ouvre une issue !

**Idées:**
- Nouveaux parsers (nginx, Apache, MySQL)
- Dashboards additionnels
- Alertes prédéfinies
- Scripts automation

---

## ✅ Checklist Déploiement

### Configuration ELK
- [ ] Fleet Server opérationnel
- [ ] Ingest pipelines créés (3x)
- [ ] GeoIP databases disponibles
- [ ] Index pattern créé

### Configuration Fleet
- [ ] Agent policy créée
- [ ] Integration fail2ban ajoutée
- [ ] Integration asterisk ajoutée
- [ ] Integration system ajoutée
- [ ] Pipelines associés aux integrations

### Configuration NUCs
- [ ] Elastic Agent installé NUC1
- [ ] Elastic Agent installé NUC2
- [ ] Agents "Healthy" dans Fleet
- [ ] Permissions logs OK

### Validation
- [ ] Data streams créés
- [ ] Logs fail2ban parsés
- [ ] Logs asterisk parsés
- [ ] Logs auth parsés
- [ ] GeoIP fonctionne
- [ ] Dashboards accessibles

---

## 🎉 Avantages Elastic Agent

### vs Filebeat
- ✅ **Configuration centralisée** (Fleet UI vs fichiers YAML)
- ✅ **Updates automatiques** (push depuis Fleet)
- ✅ **Monitoring intégré** (pas besoin Metricbeat)
- ✅ **Gestion unifiée** (logs + metrics + APM)
- ✅ **Rollback facile** (via Fleet)

### vs Logstash
- ✅ **Moins de ressources** (parsing dans ES)
- ✅ **Scalabilité native** (ingest nodes)
- ✅ **Moins de composants** (architecture simplifiée)
- ✅ **GeoIP natif** (inclus dans ES)

---

**Créé pour simplifier le monitoring sécurité avec Elastic Stack 8.x**

*Questions ? Consulte [QUICK_START.md](QUICK_START.md) ou [ELASTIC_AGENT_GUIDE.md](ELASTIC_AGENT_GUIDE.md)*
