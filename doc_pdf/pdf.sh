#!/usr/bin/env bash
# pdf.sh — Compila lab1.tex para PDF dentro do ambiente nix (texlive + abntex2).
#          Executa pdflatex duas vezes para garantir sumário correto.
#
# Uso:
#   ./pdf.sh          (de dentro de doc_pdf/)
#   doc_pdf/pdf.sh    (da raiz do projeto)
#
# Saída:
#   doc_pdf/lab1.pdf
set -e

cd "$(dirname "$0")"

echo "📄 Compilando lab1.tex → lab1.pdf"
echo ""

nix develop --command bash -c "cd '$(pwd)' && pdflatex -interaction=nonstopmode lab1.tex && pdflatex -interaction=nonstopmode lab1.tex"

echo ""
echo "✅ PDF gerado: doc_pdf/lab1.pdf"
