#!/usr/bin/env bash

echo "🚀 Inicializando repositório Git e enviando para GitHub..."

# garante que está na pasta certa
cd "$(pwd)"

# verifica se já é um repo git
if [ -d ".git" ]; then
    echo "⚠️ Já existe um repositório Git aqui"
else
    git init
    echo "✅ Git inicializado"
fi

# adiciona tudo
git add -A
echo "📦 Arquivos adicionados"

# commit inicial
git commit -m "init teoria computacao lab1"

# branch principal
git branch -M main

# remote (evita erro se já existir)
if git remote get-url origin >/dev/null 2>&1; then
    echo "⚠️ Remote origin já existe"
else
    git remote add origin git@github.com:fmiozzi/teoria-computacao-lab1.git
    echo "🔗 Remote adicionado"
fi

# push
git push -u origin main

echo "🎉 Projeto enviado com sucesso!"