#!/usr/bin/env bash

#git pull --rebase origin main
#chmod +x git-sync.sh

echo "🔄 Git Sync iniciado..."

# garante que estamos dentro de um repo git
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "❌ Erro: não é um repositório Git"
    exit 1
fi

# vai para raiz do repo (evita erro de subpasta)
cd "$(git rev-parse --show-toplevel)"

echo "📂 Repo: $(pwd)"

# adiciona TUDO (novos, modificados e removidos)
git add -A

echo "📦 Arquivos preparados:"
git status --short

# verifica se tem algo para commitar
if git diff --cached --quiet; then
    echo "⚠️ Nada para sincronizar"
    exit 0
fi

# commit automático com timestamp
git commit -m "sync: $(date '+%Y-%m-%d %H:%M:%S')"

# envia para o GitHub
git push

echo "✅ Sync concluído com sucesso!"
