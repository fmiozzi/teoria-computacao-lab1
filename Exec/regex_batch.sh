#!/usr/bin/env bash
# regex_batch.sh — Converte em lote todas as expressões regulares de Files/REGEX
#            para NFA e DFA mínimo.
#            Cada arquivo deve conter uma expressão regular na primeira linha.
#            Pipeline por arquivo:
#              Regex → NFAε (Thompson/lab1-part2)
#                    → NFA  (removeEpsilon/lab1)   → Files/REGEX_NFA/<base>.yaml
#                    → DFA mínimo (subconjuntos + minimização/lab1) → Files/REGEX_DFA/<base>.yaml
#
# Uso:
#   ./Exec/regex_batch.sh [diretório_entrada]
#
# Operadores suportados:
#   Concatenação : justaposição  (ab)
#   União        : |             (a|b)
#   Kleene       : *             (a*)
#   Uma ou mais  : +             (a+)
#   Opcional     : ?             (a?)

cd "$(dirname "$0")/.."

INPUT_DIR=${1:-Files/REGEX}
NFA_DIR=Files/REGEX_NFA
DFA_DIR=Files/REGEX_DFA

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

INNER=$(mktemp /tmp/re_batch_XXXXXX.sh)
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
  REGEX=$(head -n1 "$FILE")

  if [[ -z "$REGEX" ]]; then
    echo "⚠️  $NAME : arquivo vazio, ignorado"
    continue
  fi

  TOTAL=$((TOTAL + 1))
  NFAE_TMP=$(mktemp /tmp/nfae_XXXXXX.yaml)
  OUTPUT_NFA="${NFA_DIR}/${BASE}.yaml"
  OUTPUT_DFA="${DFA_DIR}/${BASE}.yaml"

  echo "🔤 $NAME : $REGEX"

  if cabal run lab1-part2 -- "$REGEX" "$NFAE_TMP" 2>/dev/null \
  && cabal run lab1       -- "$NFAE_TMP" "$OUTPUT_NFA" "$OUTPUT_DFA" 2>/dev/null; then
    echo "   ✅ NFA → $OUTPUT_NFA"
    echo "   ✅ DFA → $OUTPUT_DFA"
  else
    echo "   ❌ Erro ao processar: $REGEX" >&2
    ERRORS=$((ERRORS + 1))
  fi

  rm -f "$NFAE_TMP"
done

echo ""
echo "Concluído — ${TOTAL} arquivo(s) processado(s), ${ERRORS} erro(s)"
exit "$ERRORS"
INNER_EOF

nix develop --command bash "$INNER" "$INPUT_DIR" "$NFA_DIR" "$DFA_DIR"
STATUS=$?

rm -f "$INNER"
exit "$STATUS"
