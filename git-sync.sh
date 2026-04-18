#!/usr/bin/env bash
set -e

echo "🔄 Git Sync iniciado..."

# garante que estamos dentro de um repo git
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "❌ Erro: não é um repositório Git"
    exit 1
fi

# vai para raiz do repo
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "📂 Repo: $REPO_ROOT"

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
echo "🌿 Branch atual: $CURRENT_BRANCH"

echo "⬇️ Atualizando repositório remoto..."
git pull --rebase origin "$CURRENT_BRANCH" || {
    echo "❌ Erro no git pull --rebase. Resolva conflitos manualmente."
    exit 1
}

# mostra arquivos ignorados
echo "🚫 Arquivos ignorados (.gitignore):"
git status --short --ignored

# adiciona tudo
git add -A

echo "📦 Arquivos preparados:"
git status --short

# verifica se há mudanças
if git diff --cached --quiet; then
    echo "⚠️ Nada para sincronizar"
    exit 0
fi

COMMIT_MSG="sync: $(date '+%Y-%m-%d %H:%M:%S')"
git commit -m "$COMMIT_MSG"

echo "⬆️ Enviando para o remoto..."
git push origin "$CURRENT_BRANCH"

echo "✅ Sync concluído com sucesso!"