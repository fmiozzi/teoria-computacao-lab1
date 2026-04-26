#!/usr/bin/env bash
# pdf.sh — Compila lab1.tex para PDF dentro do ambiente nix (texlive + abntex2).
#          Executa pdflatex três vezes em modo silencioso e exibe apenas
#          avisos e erros reais ao final.
#
# Uso:
#   ./pdf.sh          (de dentro de doc_pdf/)
#   doc_pdf/pdf.sh    (da raiz do projeto)
#
# Saída:
#   doc_pdf/lab1.pdf

cd "$(dirname "$0")"

LOGFILE="lab1.log"

echo "📄 Compilando lab1.tex → lab1.pdf"

NIX_CMD="cd '$(pwd)' && pdflatex -interaction=batchmode lab1.tex > /dev/null && pdflatex -interaction=batchmode lab1.tex > /dev/null && pdflatex -interaction=batchmode lab1.tex > /dev/null"

if ! nix develop --command bash -c "$NIX_CMD" 2>&1 \
    | grep -v "does not contain a 'flake.nix'\|Git tree.*is dirty\|searching up\|carregado" \
    | grep -v "^$"; then
  :  # saída já filtrada acima; erros reais aparecerão
fi

# Verificar se o PDF foi gerado
if [ ! -f "lab1.pdf" ]; then
  echo "❌ Falha: lab1.pdf não foi gerado. Verifique lab1.log."
  exit 1
fi

# Exibir apenas avisos/erros reais do log
WARNINGS=$(grep -E "^(! |.*Warning:|.*Error:|Underfull|Overfull)" "$LOGFILE" \
  | grep -v "^Package.*Info:\|^LaTeX Font Info:\|^LaTeX Info:" \
  | grep -v "^$")

echo ""
if [ -n "$WARNINGS" ]; then
  echo "⚠️  Avisos da compilação:"
  echo "$WARNINGS"
else
  echo "✅ PDF gerado sem avisos: doc_pdf/lab1.pdf"
fi
