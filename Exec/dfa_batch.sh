#!/usr/bin/env bash
# dfa_batch.sh — Converte em lote todos os autômatos de Files/NFAe para DFA mínimo.
#          Pipeline por arquivo (conforme tipo de entrada):
#            NFAε → NFA → DFA mínimo → Files/NFA/<nome> e Files/DFA/<nome>
#            NFA  →       DFA mínimo → Files/NFA/<nome> e Files/DFA/<nome>
#            DFA  →       DFA mínimo → Files/NFA/<nome> e Files/DFA/<nome>
#
# Uso:
#   ./Exec/dfa_batch.sh [diretório_entrada]

cd "$(dirname "$0")/.."

INPUT_DIR=${1:-Files/NFAe}
NFA_DIR=Files/NFA
DFA_DIR=Files/DFA

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "Erro: diretório de entrada não encontrado: $INPUT_DIR" >&2
  exit 1
fi

mkdir -p "$NFA_DIR" "$DFA_DIR"

shopt -s nullglob
FILES=("$INPUT_DIR"/*)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "Nenhum arquivo encontrado em $INPUT_DIR"
  exit 0
fi

echo "📂 Entrada : $INPUT_DIR  (${#FILES[@]} arquivo(s))"
echo "📤 NFA     : $NFA_DIR"
echo "📤 DFA     : $DFA_DIR"
echo ""

INNER=$(mktemp /tmp/fa_batch_XXXXXX.sh)
cat > "$INNER" << 'INNER_EOF'
#!/usr/bin/env bash
INPUT_DIR="$1"
NFA_DIR="$2"
DFA_DIR="$3"
ERRORS=0
TOTAL=0

for FILE in "$INPUT_DIR"/*; do
  [[ -f "$FILE" ]] || continue

  NAME=$(basename "$FILE")
  BASE="${NAME%.*}"
  OUTPUT_NFA="${NFA_DIR}/${BASE}.yaml"
  OUTPUT_DFA="${DFA_DIR}/${BASE}.yaml"

  TOTAL=$((TOTAL + 1))
  echo "📥 $NAME"

  if cabal run lab1 -- "$FILE" "$OUTPUT_NFA" "$OUTPUT_DFA" 2>/dev/null; then
    echo "   ✅ NFA → $OUTPUT_NFA"
    echo "   ✅ DFA → $OUTPUT_DFA"
  else
    echo "   ❌ Erro ao processar: $FILE" >&2
    ERRORS=$((ERRORS + 1))
  fi
done

echo ""
echo "Concluído — ${TOTAL} arquivo(s) processado(s), ${ERRORS} erro(s)"
exit "$ERRORS"
INNER_EOF

nix develop --command bash "$INNER" "$INPUT_DIR" "$NFA_DIR" "$DFA_DIR"
STATUS=$?

rm -f "$INNER"
exit "$STATUS"
