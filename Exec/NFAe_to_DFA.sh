#!/usr/bin/env bash
# NFAe_to_DFA.sh — Converte um autômato (NFAε/NFA/DFA) para NFA e DFA mínimo.
#          Pipeline de acordo com o tipo do autômato de entrada:
#            NFAε → NFA → DFA mínimo
#            NFA  →       DFA mínimo
#            DFA  →       DFA mínimo (minimização)
#
# Uso:
#   ./Exec/NFAe_to_DFA.sh <input.yaml> [output_nfa.yaml] [output_dfa.yaml]
#
# Exemplos:
#   ./Exec/NFAe_to_DFA.sh Files/NFAe/nfae_simple.yaml
#   ./Exec/NFAe_to_DFA.sh input/meu_nfa.yaml output/NFA/resultado.yaml output/DFA/resultado.yaml
set -e

cd "$(dirname "$0")/.."

INPUT=${1:?"Uso: ./Exec/NFAe_to_DFA.sh <input.yaml> [output_nfa.yaml] [output_dfa.yaml]"}
NAME=$(basename "$INPUT")
OUTPUT_NFA=${2:-output/NFA/$NAME}
OUTPUT_DFA=${3:-output/DFA/$NAME}

mkdir -p "$(dirname "$OUTPUT_NFA")" "$(dirname "$OUTPUT_DFA")"

echo "📥 Input      : $INPUT"
echo "📤 Output NFA : $OUTPUT_NFA"
echo "📤 Output DFA : $OUTPUT_DFA"
echo ""

INNER=$(mktemp /tmp/fa_conv_XXXXXX.sh)
cat > "$INNER" << 'INNER_EOF'
#!/usr/bin/env bash
cabal run lab1 -- "$1" "$2" "$3"
INNER_EOF

nix develop --command bash "$INNER" "$INPUT" "$OUTPUT_NFA" "$OUTPUT_DFA"
STATUS=$?

rm -f "$INNER"
exit "$STATUS"
