# Guide de Synchronisation avec Upstream

**Repository:** sherifabdlnaby/elastdocker
**Branche custom:** `feature/custom-optimizations-2025-01-27`
**Date:** 2025-01-27

---

## 📋 Table des Matières

1. [Architecture Git Multi-Remote](#architecture-git-multi-remote)
2. [Stratégies de Synchronisation](#stratégies-de-synchronisation)
3. [Workflows Recommandés](#workflows-recommandés)
4. [Scripts d'Automatisation](#scripts-dautomatisation)
5. [Gestion des Conflits](#gestion-des-conflits)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)

---

## 🌳 Architecture Git Multi-Remote

### Configuration Actuelle

```
┌─────────────────────────────────────────────────────────┐
│             GitHub: sherifabdlnaby/elastdocker          │
│                    (UPSTREAM)                           │
│                                                         │
│  Branches:                                             │
│  - main (ES 9.2.3)                                     │
│  - 7.9.3                                               │
│  - restore-kibana                                      │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ git fetch upstream
                     │ git pull upstream main
                     ▼
┌─────────────────────────────────────────────────────────┐
│           Local Repository (votre machine)              │
│                                                         │
│  Remotes:                                              │
│  - origin → sherifabdlnaby/elastdocker                 │
│  - upstream → sherifabdlnaby/elastdocker (alias)       │
│                                                         │
│  Branches Locales:                                     │
│  - main (tracking origin/main)                         │
│  - develop (votre branche de travail)                  │
│  - feature/custom-optimizations-2025-01-27 ✅          │
│    └─ Vos customisations (8,100+ lignes docs)         │
│                                                         │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ git push origin
                     ▼
┌─────────────────────────────────────────────────────────┐
│        GitHub: VotreUsername/elastdocker (FORK)         │
│                    (OPTIONNEL)                          │
│                                                         │
│  Branches:                                             │
│  - main (synced with upstream)                         │
│  - feature/custom-optimizations-2025-01-27             │
│  - production (stable releases)                        │
└─────────────────────────────────────────────────────────┘
```

### Setup Configuration Git

```bash
#!/bin/bash
# scripts/setup-git-remotes.sh

set -euo pipefail

echo "🔧 Configuring Git remotes for upstream synchronization"

# 1. Vérifier remote actuel
echo "Current remotes:"
git remote -v

# 2. Si pas déjà configuré, ajouter upstream comme alias
if ! git remote | grep -q "^upstream$"; then
    git remote add upstream https://github.com/sherifabdlnaby/elastdocker.git
    echo "✅ Added upstream remote"
else
    echo "✓ Upstream remote already exists"
fi

# 3. Fetch toutes les branches upstream
git fetch upstream

# 4. Configurer fetch automatique des tags
git config remote.upstream.tagopt --tags

# 5. Afficher configuration
echo ""
echo "Git remotes configured:"
git remote -v

echo ""
echo "Upstream branches available:"
git branch -r | grep upstream

echo ""
echo "✅ Git remotes configured successfully"
echo ""
echo "Next steps:"
echo "1. Sync with upstream: ./scripts/sync-upstream.sh"
echo "2. Or manual: git fetch upstream && git merge upstream/main"
```

**Exécuter:**
```bash
chmod +x scripts/setup-git-remotes.sh
./scripts/setup-git-remotes.sh
```

---

## 🔄 Stratégies de Synchronisation

### Stratégie 1: Cherry-Pick Sélectif (RECOMMANDÉ)

**Quand utiliser:**
- Vous voulez garder vos customisations intactes
- Vous voulez uniquement certains commits upstream
- Production critique (risque minimal)

**Avantages:**
- ✅ Contrôle total sur ce qui est intégré
- ✅ Pas de conflits massifs
- ✅ Garde stabilité
- ✅ Historique Git clair

**Inconvénients:**
- ⚠️ Travail manuel de sélection
- ⚠️ Peut manquer des dépendances entre commits

**Processus:**

```bash
#!/bin/bash
# scripts/cherry-pick-upstream.sh

set -euo pipefail

echo "🍒 Cherry-picking selected commits from upstream"

# 1. Fetch latest upstream
git fetch upstream

# 2. Voir nouveaux commits upstream
echo "New commits in upstream/main:"
git log HEAD..upstream/main --oneline | head -20

# 3. Cherry-pick commits spécifiques (exemples)
# Remplacer par les commits SHA que vous voulez

COMMITS_TO_PICK=(
    "46ef7ed"  # Fix docker volume prune command
    "38bc18b"  # Introduce variables for docker images
    "af52c3b"  # Use project name for prune
    # Ajouter d'autres commits ici
)

for commit in "${COMMITS_TO_PICK[@]}"; do
    echo "Picking commit $commit..."

    if git cherry-pick "$commit"; then
        echo "✅ Successfully picked $commit"
    else
        echo "⚠️  Conflict in $commit - resolve manually"
        echo "After resolving: git cherry-pick --continue"
        echo "To abort: git cherry-pick --abort"
        exit 1
    fi
done

echo "✅ All commits cherry-picked successfully"
```

**Workflow manuel:**

```bash
# 1. Fetch upstream
git fetch upstream

# 2. Voir les commits intéressants
git log upstream/main --oneline -20

# 3. Cherry-pick un commit spécifique
git cherry-pick 46ef7ed

# 4. Si conflit, résoudre puis:
git add .
git cherry-pick --continue

# 5. Pousser sur votre branche
git push origin feature/custom-optimizations-2025-01-27
```

---

### Stratégie 2: Merge Régulier (Branche Tracking)

**Quand utiliser:**
- Environnement de développement
- Vous voulez toutes les nouveautés upstream
- Vous avez du temps pour résoudre conflits

**Avantages:**
- ✅ À jour avec toutes les features upstream
- ✅ Pas de commits manquants
- ✅ Workflow Git standard

**Inconvénients:**
- ⚠️ Conflits fréquents à résoudre
- ⚠️ Peut casser vos customisations
- ⚠️ Nécessite tests exhaustifs après merge

**Processus:**

```bash
#!/bin/bash
# scripts/merge-upstream.sh

set -euo pipefail

echo "🔀 Merging upstream changes"

# 1. Sauvegarder état actuel
BRANCH=$(git branch --show-current)
echo "Current branch: $BRANCH"

# 2. Créer backup branch
BACKUP_BRANCH="${BRANCH}-backup-$(date +%Y%m%d-%H%M%S)"
git branch "$BACKUP_BRANCH"
echo "✅ Backup branch created: $BACKUP_BRANCH"

# 3. Fetch upstream
git fetch upstream

# 4. Voir les changements
echo ""
echo "Changes in upstream/main since last sync:"
git log HEAD..upstream/main --oneline

echo ""
read -p "Continue with merge? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Merge cancelled"
    exit 0
fi

# 5. Merge upstream/main
echo "Merging upstream/main into $BRANCH..."
if git merge upstream/main --no-edit; then
    echo "✅ Merge successful - no conflicts"
else
    echo "⚠️  Merge conflicts detected"
    echo ""
    echo "Conflicted files:"
    git diff --name-only --diff-filter=U
    echo ""
    echo "To resolve:"
    echo "1. Edit conflicted files"
    echo "2. git add <resolved-files>"
    echo "3. git commit"
    echo ""
    echo "To abort merge:"
    echo "git merge --abort"
    echo "git checkout $BACKUP_BRANCH"
    exit 1
fi

# 6. Tests automatiques (si configurés)
echo ""
echo "Running tests..."
# docker compose config  # Valider syntax
# make test  # Si tests définis

echo ""
echo "✅ Merge completed successfully"
echo "Backup available at: $BACKUP_BRANCH"
echo ""
echo "Next steps:"
echo "1. Test thoroughly: make elk && ./scripts/health-check.sh"
echo "2. If OK: git push origin $BRANCH"
echo "3. If issues: git reset --hard $BACKUP_BRANCH"
```

**Workflow manuel:**

```bash
# 1. Créer backup
git branch backup-before-merge

# 2. Fetch et merge
git fetch upstream
git merge upstream/main

# 3. Si conflits:
git status  # Voir fichiers en conflit
# Éditer et résoudre
git add .
git commit

# 4. Tester
docker compose config
docker compose up -d
./scripts/health-check.sh

# 5. Push
git push origin feature/custom-optimizations-2025-01-27
```

---

### Stratégie 3: Rebase (Clean History)

**Quand utiliser:**
- Vous voulez historique Git propre
- Contributions open source
- Avant de créer Pull Request

**Avantages:**
- ✅ Historique linéaire propre
- ✅ Pas de merge commits
- ✅ Facilite code review

**Inconvénients:**
- ⚠️ Réécrit l'historique Git
- ⚠️ Dangereux si branche partagée
- ⚠️ Conflits à résoudre commit par commit

**Processus:**

```bash
#!/bin/bash
# scripts/rebase-upstream.sh

set -euo pipefail

echo "⚡ Rebasing on upstream (ATTENTION: Réécrit historique)"

# 1. Vérifier que branche n'est pas pushée/partagée
BRANCH=$(git branch --show-current)

if git branch -r | grep -q "origin/$BRANCH"; then
    echo "⚠️  WARNING: Branch $BRANCH existe sur remote"
    echo "Rebase va réécrire historique - OK seulement si branche non partagée"
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Rebase cancelled"
        exit 0
    fi
fi

# 2. Backup
BACKUP_BRANCH="${BRANCH}-backup-$(date +%Y%m%d-%H%M%S)"
git branch "$BACKUP_BRANCH"
echo "✅ Backup: $BACKUP_BRANCH"

# 3. Fetch upstream
git fetch upstream

# 4. Rebase interactif (permet de skip/edit commits)
git rebase -i upstream/main

# Note: En cas de conflit:
# - Résoudre le conflit
# - git add <file>
# - git rebase --continue
#
# Pour annuler:
# - git rebase --abort
# - git checkout $BACKUP_BRANCH

echo ""
echo "✅ Rebase completed"
echo "⚠️  Historique a été réécrit"
echo ""
echo "Si branche était pushée, force push requis:"
echo "git push origin $BRANCH --force-with-lease"
```

**⚠️ ATTENTION:** Ne jamais rebaser une branche déjà partagée avec d'autres développeurs !

---

### Stratégie 4: Branche de Tracking (Hybrid)

**Architecture recommandée pour production:**

```
main (pristine upstream)
│
├─ develop (vos customisations)
│  │
│  ├─ feature/custom-optimizations-2025-01-27
│  └─ feature/new-feature-X
│
└─ upstream-sync (staging pour nouveautés)
   └─ Test des nouveautés upstream avant merge dans develop
```

**Setup:**

```bash
#!/bin/bash
# scripts/setup-tracking-branches.sh

set -euo pipefail

# 1. Main = pristine upstream (jamais modifié)
git checkout main
git branch --set-upstream-to=upstream/main main
echo "✅ main tracks upstream/main"

# 2. Develop = votre branche de travail
if ! git rev-parse --verify develop >/dev/null 2>&1; then
    git checkout -b develop main
    echo "✅ develop branch created from main"
fi

# 3. Upstream-sync = staging pour nouveautés
if ! git rev-parse --verify upstream-sync >/dev/null 2>&1; then
    git checkout -b upstream-sync upstream/main
    echo "✅ upstream-sync branch created"
fi

echo ""
echo "Branch structure:"
git branch -vv

echo ""
echo "Workflow:"
echo "1. Main: git checkout main && git pull (pristine upstream)"
echo "2. Upstream-sync: git checkout upstream-sync && git pull upstream main (test nouveautés)"
echo "3. Develop: cherry-pick from upstream-sync after testing"
```

**Workflow quotidien:**

```bash
# Morning: Sync main avec upstream
git checkout main
git pull upstream main
git push origin main  # Si vous avez un fork

# Weekly: Test nouvelles features dans upstream-sync
git checkout upstream-sync
git rebase main
docker compose up -d
# ... tests ...

# Monthly: Intégrer dans develop si OK
git checkout develop
git cherry-pick <commits-from-upstream-sync>
```

---

## 🤖 Scripts d'Automatisation

### Script de Synchronisation Automatique

```bash
#!/bin/bash
# scripts/sync-upstream.sh - Synchronisation automatique intelligente

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
UPSTREAM_REMOTE="upstream"
UPSTREAM_BRANCH="main"
LOCAL_BRANCH=$(git branch --show-current)
DRY_RUN=false
AUTO_MERGE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --auto-merge)
            AUTO_MERGE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--dry-run] [--auto-merge]"
            exit 1
            ;;
    esac
done

echo "╔═══════════════════════════════════════╗"
echo "║   Upstream Synchronization Tool      ║"
echo "╚═══════════════════════════════════════╝"
echo ""
echo "Repository: $PROJECT_DIR"
echo "Current branch: $LOCAL_BRANCH"
echo "Upstream: $UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
echo "Mode: $([ "$DRY_RUN" = true ] && echo "DRY RUN" || echo "LIVE")"
echo ""

# 1. Vérifier que Git est propre
if [[ -n $(git status --porcelain) ]]; then
    echo "❌ Git working directory not clean"
    echo "Commit or stash changes first"
    exit 1
fi

# 2. Fetch upstream
echo "📥 Fetching from upstream..."
git fetch "$UPSTREAM_REMOTE" --tags

# 3. Comparer avec upstream
COMMITS_BEHIND=$(git rev-list HEAD.."${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH}" --count)
COMMITS_AHEAD=$(git rev-list "${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH}"..HEAD --count)

echo ""
echo "Status:"
echo "  Commits behind upstream: $COMMITS_BEHIND"
echo "  Commits ahead of upstream: $COMMITS_AHEAD"

if [[ $COMMITS_BEHIND -eq 0 ]]; then
    echo "✅ Already up to date with upstream"
    exit 0
fi

# 4. Lister nouveaux commits upstream
echo ""
echo "New commits in upstream:"
git log --oneline HEAD.."${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH}" | head -20

# 5. Analyser type de changements
echo ""
echo "Files changed in upstream:"
CHANGED_FILES=$(git diff --name-only HEAD "${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH}")
echo "$CHANGED_FILES"

# 6. Détecter conflits potentiels
echo ""
echo "Potential conflicts:"
CUSTOM_FILES=(
    "elasticsearch/config/elasticsearch.yml"
    "logstash/config/pipelines.yml"
    "logstash/pipeline/freqtrade.conf"
    "docker-compose.yml"
    ".env"
)

CONFLICTS=false
for file in "${CUSTOM_FILES[@]}"; do
    if echo "$CHANGED_FILES" | grep -q "$file"; then
        echo "⚠️  $file (modified both locally and upstream)"
        CONFLICTS=true
    fi
done

if [[ "$CONFLICTS" = false ]]; then
    echo "✓ No conflicts detected in custom files"
fi

# 7. Dry run mode
if [[ "$DRY_RUN" = true ]]; then
    echo ""
    echo "🔍 DRY RUN - No changes made"
    echo ""
    echo "To merge: $0 --auto-merge"
    echo "Or manually: git merge ${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH}"
    exit 0
fi

# 8. Demander confirmation (sauf si auto-merge)
if [[ "$AUTO_MERGE" = false ]]; then
    echo ""
    read -p "Proceed with merge? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Merge cancelled"
        exit 0
    fi
fi

# 9. Créer backup automatique
BACKUP_BRANCH="${LOCAL_BRANCH}-backup-$(date +%Y%m%d-%H%M%S)"
git branch "$BACKUP_BRANCH"
echo "✅ Backup created: $BACKUP_BRANCH"

# 10. Merger upstream
echo ""
echo "🔀 Merging upstream..."
if git merge "${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH}" --no-edit; then
    echo "✅ Merge successful"

    # 11. Validation automatique
    echo ""
    echo "🧪 Validating configuration..."

    if docker compose config >/dev/null 2>&1; then
        echo "✅ Docker Compose syntax valid"
    else
        echo "❌ Docker Compose validation failed"
        echo "Rolling back..."
        git reset --hard "$BACKUP_BRANCH"
        exit 1
    fi

    echo ""
    echo "✅ Synchronization completed successfully"
    echo ""
    echo "Next steps:"
    echo "1. Test: docker compose up -d"
    echo "2. Verify: ./scripts/health-check.sh"
    echo "3. If OK: git push origin $LOCAL_BRANCH"
    echo "4. If issues: git reset --hard $BACKUP_BRANCH"
else
    echo "❌ Merge conflicts detected"
    echo ""
    echo "Conflicted files:"
    git diff --name-only --diff-filter=U
    echo ""
    echo "To resolve:"
    echo "1. Edit conflicted files"
    echo "2. git add <resolved-files>"
    echo "3. git commit"
    echo ""
    echo "To abort:"
    echo "git merge --abort"
    echo "git checkout $BACKUP_BRANCH"
    exit 1
fi
```

### Script de Monitoring des Nouveautés

```bash
#!/bin/bash
# scripts/check-upstream-updates.sh - Vérifier nouveautés upstream

set -euo pipefail

UPSTREAM_REMOTE="upstream"
UPSTREAM_BRANCH="main"

# Fetch silencieusement
git fetch "$UPSTREAM_REMOTE" --quiet

# Compter nouveaux commits
COMMITS_BEHIND=$(git rev-list HEAD.."${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH}" --count)

if [[ $COMMITS_BEHIND -eq 0 ]]; then
    echo "✓ Up to date with upstream ($UPSTREAM_REMOTE/$UPSTREAM_BRANCH)"
    exit 0
fi

echo "⚠️  $COMMITS_BEHIND new commits in upstream"
echo ""
echo "Recent changes:"
git log --oneline --no-merges HEAD.."${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH}" | head -10
echo ""
echo "To sync: ./scripts/sync-upstream.sh --dry-run"
```

**Ajouter à cron:**

```bash
# Check upstream updates daily at 9 AM
0 9 * * * cd /home/admsrv/elastdocker && ./scripts/check-upstream-updates.sh | mail -s "ElasticDocker Upstream Updates" admin@example.com
```

---

## 🛠️ Gestion des Conflits

### Fichiers avec Conflits Fréquents

#### 1. elasticsearch/config/elasticsearch.yml

**Conflit type:**
```yaml
<<<<<<< HEAD (votre version)
# Performance tuning
indices.memory.index_buffer_size: 20%
thread_pool.write.queue_size: 1000
=======
# ES 9 specific config
cluster.deprecation_indexing.enabled: false
>>>>>>> upstream/main
```

**Résolution recommandée:**
```yaml
# Garder LES DEUX (merge manuel)
# Performance tuning (custom)
indices.memory.index_buffer_size: 20%
thread_pool.write.queue_size: 1000

# ES 9 specific config (upstream)
cluster.deprecation_indexing.enabled: false
```

**Commandes:**
```bash
# Ouvrir dans éditeur
vim elasticsearch/config/elasticsearch.yml

# Supprimer marqueurs de conflit (<<<, ===, >>>)
# Combiner les changements intelligemment

# Marquer comme résolu
git add elasticsearch/config/elasticsearch.yml
```

#### 2. logstash/config/pipelines.yml

**Conflit type:**
```yaml
<<<<<<< HEAD (votre version)
# FreqTrade pipeline optimisé
- pipeline.id: freqtrade
  queue.type: persisted
  pipeline.batch.size: 250
  pipeline.workers: 2
=======
# Upstream format
- pipeline.id: main
  path.config: "/usr/share/logstash/pipeline/main.conf"
>>>>>>> upstream/main
```

**Résolution:**
```yaml
# Garder votre pipeline freqtrade + ajouter changements upstream
- pipeline.id: main
  path.config: "/usr/share/logstash/pipeline/main.conf"
  queue.type: persisted  # De votre version

- pipeline.id: freqtrade
  path.config: "/usr/share/logstash/pipeline/freqtrade.conf"
  queue.type: persisted
  pipeline.batch.size: 250
  pipeline.workers: 2
```

#### 3. docker-compose.yml

**Stratégie:**
- Garder structure upstream
- Ajouter vos customisations (volumes FreqTrade, etc.)
- Utiliser variables d'environnement pour flexibilité

### Outils pour Résolution Conflits

**1. Vimdiff (terminal):**
```bash
git config merge.tool vimdiff
git config merge.conflictstyle diff3
git mergetool
```

**2. VSCode (GUI):**
```bash
code --wait --diff HEAD MERGE_HEAD
```

**3. Outil de merge graphique:**
```bash
# Installer meld
sudo apt-get install meld

# Configurer Git
git config merge.tool meld
git config mergetool.meld.path /usr/bin/meld

# Utiliser
git mergetool
```

---

## 📚 Best Practices

### 1. Principe de Séparation

**Garder séparés:**
- ✅ Configuration upstream (fichiers de base)
- ✅ Vos customisations (dans dossiers séparés si possible)
- ✅ Documentation (vos fichiers `.md`)
- ✅ Scripts automation (votre dossier `scripts/`)

**Exemple structure:**
```
elastdocker/
├── docker-compose.yml          # Upstream (minimiser modifications)
├── docker-compose.override.yml # VOS customisations
├── .env.example                # Upstream
├── .env                        # Votre config (gitignored)
├── elasticsearch/
│   └── config/
│       ├── elasticsearch.yml   # Upstream + vos optimisations
│       └── elasticsearch-custom.yml  # VOS configs additionnelles
├── scripts/                    # VOS scripts (pas upstream)
│   ├── backup-elasticsearch.sh
│   └── sync-upstream.sh
└── docs/                       # VOTRE documentation
    ├── CLAUDE.md
    ├── SECURITY_APM_FLEET.md
    └── ...
```

### 2. Convention de Commits

**Pour faciliter synchronisation:**

```bash
# Vos commits custom
feat: Add custom backup script
fix: Optimize Elasticsearch heap size
docs: Add comprehensive security guide

# Commits upstream (après merge)
merge: Sync with upstream main (ES 9.2.3)
upstream: Cherry-pick fix volume prune command
```

### 3. Tagging des Releases

```bash
# Créer tag pour vos releases stables
git tag -a v1.0.0-custom -m "Stable release with all optimizations"
git push origin v1.0.0-custom

# Tag format recommandé:
# v<upstream-version>-custom-<your-version>
# Exemple: v8.10.2-custom-1.0.0
```

### 4. Documentation des Modifications

**Maintenir fichier MODIFICATIONS.md:**

```markdown
# Modifications vs Upstream

## Fichiers Modifiés
- elasticsearch/config/elasticsearch.yml
  - Added: Performance tuning (indices.memory.index_buffer_size: 20%)
  - Added: Circuit breakers configuration

- logstash/config/pipelines.yml
  - Added: FreqTrade pipeline with optimizations
  - Changed: Main pipeline to persisted queue

## Fichiers Ajoutés (Custom)
- scripts/* (tous nos scripts)
- *.md (toute notre documentation)
- .env.example (template sécurisé)

## Conflits Connus avec Upstream
- elasticsearch.yml: Performance tuning vs ES 9 configs
- pipelines.yml: Pipeline freqtrade custom

## Résolution Conflits
- Toujours garder nos optimisations
- Ajouter nouveautés upstream en plus
- Tester avant de merger
```

---

## 🔍 Troubleshooting

### Problème 1: "Divergent branches"

**Erreur:**
```
fatal: Not possible to fast-forward, aborting.
```

**Solution:**
```bash
# Option 1: Merge (historique non-linéaire)
git pull upstream main --no-rebase

# Option 2: Rebase (historique linéaire)
git pull upstream main --rebase

# Option 3: Annuler et recommencer
git merge --abort
git fetch upstream
git merge upstream/main
```

### Problème 2: "Trop de conflits"

**Situation:** Merge upstream crée 50+ conflits

**Solution recommandée:**
```bash
# 1. Annuler merge difficile
git merge --abort

# 2. Créer branche propre depuis upstream
git checkout -b clean-upstream upstream/main

# 3. Cherry-pick VOS commits un par un
git cherry-pick <votre-commit-sha>

# 4. Résoudre conflits au fur et à mesure
# (Plus facile commit par commit)

# 5. Une fois fini, remplacer votre branche
git branch -D feature/custom-optimizations-2025-01-27
git branch -m feature/custom-optimizations-2025-01-27
```

### Problème 3: "Lost my changes after merge"

**Solution:**
```bash
# Git garde TOUT dans reflog (30 jours)
git reflog

# Trouver votre état avant merge
# Exemple: HEAD@{2} = "Before merge"

# Revenir à cet état
git reset --hard HEAD@{2}

# Ou créer branche depuis cet état
git branch recovery HEAD@{2}
```

### Problème 4: "Upstream changed file structure"

**Exemple:** Upstream a déplacé `elasticsearch/config/` vers `config/elasticsearch/`

**Solution:**
```bash
# 1. Accepter changements upstream (structure)
git checkout --theirs <file-path>

# 2. Réappliquer vos modifications manuellement
# Copier vos changements depuis backup ou ancien fichier

# 3. Commit
git add .
git commit -m "fix: Adapt to upstream file structure changes"
```

---

## 📅 Calendrier de Synchronisation Recommandé

### Quotidien (Automatisé)
```bash
# Cron: Check upstream updates
0 9 * * * cd /home/admsrv/elastdocker && ./scripts/check-upstream-updates.sh
```

### Hebdomadaire (Manuel)
```bash
# Review nouveaux commits upstream
./scripts/sync-upstream.sh --dry-run

# Si pertinent, cherry-pick
./scripts/cherry-pick-upstream.sh
```

### Mensuel (Planifié)
```bash
# Sync complète avec tests
# Prévoir 2-4 heures

1. Backup complet
2. ./scripts/sync-upstream.sh
3. Résoudre conflits
4. Tests exhaustifs (dev environment)
5. Deploy en production si OK
```

### Trimestriel (Major Updates)
```bash
# Migration version majeure (ex: 8.x → 9.x)
# Prévoir 1-2 jours

1. Créer branche test-es9
2. Merge upstream/main (ES 9.x)
3. Tests complets (1 semaine)
4. Migration production (weekend)
```

---

## 🎯 Checklist Synchronisation

### Avant Sync
- [ ] ✅ Git working directory propre
- [ ] ✅ Backup branche créé
- [ ] ✅ Upstream fetched (`git fetch upstream`)
- [ ] ✅ Review nouveaux commits (`git log HEAD..upstream/main`)
- [ ] ✅ Identifier fichiers en conflit potentiel

### Pendant Sync
- [ ] ✅ Merge/Cherry-pick exécuté
- [ ] ✅ Conflits résolus intelligemment (garder nos optimisations)
- [ ] ✅ Docker Compose syntax validée
- [ ] ✅ Commit avec message clair

### Après Sync
- [ ] ✅ Services démarrent correctement
- [ ] ✅ Health-check passe (`./scripts/health-check.sh`)
- [ ] ✅ Tests fonctionnels OK
- [ ] ✅ Documentation updated (MODIFICATIONS.md)
- [ ] ✅ Push vers remote
- [ ] ✅ Tag si release stable

---

## 📖 Résumé Workflows

### Workflow 1: Développeur Solo (Simple)

```bash
# Setup (une fois)
git remote add upstream https://github.com/sherifabdlnaby/elastdocker.git

# Quotidien
git fetch upstream

# Hebdomadaire
git checkout main
git pull upstream main
git checkout develop
git merge main  # Ou cherry-pick commits intéressants

# Mensuel
Tag release stable
```

### Workflow 2: Équipe (Collaboratif)

```bash
# Setup (une fois)
git remote add upstream https://github.com/sherifabdlnaby/elastdocker.git
git remote add origin https://github.com/votre-org/elastdocker.git

# Main = pristine upstream
git checkout main
git pull upstream main
git push origin main

# Develop = vos customisations
git checkout develop
git merge main
git push origin develop

# Feature branches pour chaque feature
git checkout -b feature/new-optimization develop
# ... work ...
git push origin feature/new-optimization
# Create Pull Request vers develop
```

### Workflow 3: Production (Enterprise)

```bash
# Branches:
# - main: pristine upstream
# - staging: test nouveautés upstream
# - production: stable, deployed

# Weekly: Update staging
git checkout staging
git pull upstream main
# Tests exhaustifs (CI/CD)

# Monthly: Deploy to production (si staging OK)
git checkout production
git merge staging --ff-only
git tag v1.2.0-prod
git push origin production --tags
# Deploy automation triggered
```

---

## 🔗 Ressources

### Git Documentation
- [Git Branching Strategies](https://git-scm.com/book/en/v2/Git-Branching-Branching-Workflows)
- [Git Merge vs Rebase](https://www.atlassian.com/git/tutorials/merging-vs-rebasing)
- [Resolving Merge Conflicts](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/addressing-merge-conflicts)

### Upstream Repository
- [sherifabdlnaby/elastdocker](https://github.com/sherifabdlnaby/elastdocker)
- [Releases](https://github.com/sherifabdlnaby/elastdocker/releases)
- [Changelog](https://github.com/sherifabdlnaby/elastdocker/commits/main)

### Outils
- [Meld](https://meldmerge.org/) - Merge tool graphique
- [Beyond Compare](https://www.scootersoftware.com/) - Diff/merge pro
- [GitKraken](https://www.gitkraken.com/) - Git GUI

---

**Document créé:** 2025-01-27
**Auteur:** Claude (Anthropic)
**Version:** 1.0.0

---

## ✅ TL;DR

**Rester à jour avec upstream en 3 commandes:**

```bash
# 1. Setup (une fois)
git remote add upstream https://github.com/sherifabdlnaby/elastdocker.git
git fetch upstream

# 2. Voir nouveautés
git log HEAD..upstream/main --oneline

# 3. Synchroniser (choisir une méthode)
# Option A: Cherry-pick sélectif (recommandé)
git cherry-pick <commit-sha>

# Option B: Merge complet
git merge upstream/main

# Option C: Script automatique
./scripts/sync-upstream.sh --dry-run
```

**Et c'est tout ! 🎉**
