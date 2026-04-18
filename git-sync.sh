#!/usr/bin/env bash
set -e

echo "🔄 Git Sync iniciado..."

# =============================
# Validação
# =============================

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "❌ Erro: não é um repositório Git"
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "📂 Repo: $REPO_ROOT"

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
echo "🌿 Branch: $CURRENT_BRANCH"

# =============================
# Detecta alterações locais
# =============================

STASHED=0

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "⚠️ Alterações locais detectadas → salvando temporariamente (stash)"
    git stash push -u -m "auto-stash git-sync"
    STASHED=1
fi

# =============================
# Atualiza remoto
# =============================

echo "⬇️ Pull com rebase..."
if ! git pull --rebase origin "$CURRENT_BRANCH"; then
    echo "❌ Erro no pull. Resolva conflitos manualmente."
    exit 1
fi

# =============================
# Restaura alterações locais
# =============================

if [ "$STASHED" = "1" ]; then
    echo "🔄 Restaurando alterações locais..."
    if ! git stash pop; then
        echo "⚠️ Conflito ao aplicar stash. Resolva manualmente."
        exit 1
    fi
fi

# =============================
# Adiciona tudo
# =============================

git add -A

# =============================
# Verifica mudanças
# =============================

if git diff --cached --quiet; then
    echo "⚠️ Nada para commitar"
else
    COMMIT_MSG="sync: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "📦 Commitando: $COMMIT_MSG"
    git commit -m "$COMMIT_MSG"
fi

# =============================
# Push
# =============================

echo "⬆️ Enviando para remoto..."
git push origin "$CURRENT_BRANCH"

echo "✅ Sync concluído com sucesso!"