#!/usr/bin/env bash
# rgx_to_dfa.sh — Converte uma expressão regular diretamente para NFA e DFA mínimo.
#           Pipeline completo:
#             Regex → NFAε (Thompson/lab1-part2)
#                   → NFA  (removeEpsilon/lab1)   → output_nfa.yaml
#                   → DFA mínimo (subconjuntos + minimização/lab1) → output_dfa.yaml
#
# Uso:
#   ./Exec/rgx_to_dfa.sh "<regex>" [output_nfa.yaml] [output_dfa.yaml]
#
# Exemplos:
#   ./Exec/rgx_to_dfa.sh "(a|b)*abb"
#   ./Exec/rgx_to_dfa.sh "a*b+" output/REGEX_NFA/resultado.yaml output/REGEX_DFA/resultado.yaml
#
# Operadores suportados:
#   Concatenação : justaposição  (ab)
#   União        : |             (a|b)
#   Kleene       : *             (a*)
#   Uma ou mais  : +             (a+)
#   Opcional     : ?             (a?)
set -e

cd "$(dirname "$0")/.."

REGEX=${1:?"Uso: ./Exec/rgx_to_dfa.sh '<regex>' [output_nfa.yaml] [output_dfa.yaml]"}
OUTPUT_NFA=${2:-output/REGEX_NFA/result.yaml}
OUTPUT_DFA=${3:-output/REGEX_DFA/result.yaml}

mkdir -p "$(dirname "$OUTPUT_NFA")" "$(dirname "$OUTPUT_DFA")"

echo "🔤 Regex      : $REGEX"
echo "📤 Output NFA : $OUTPUT_NFA"
echo "📤 Output DFA : $OUTPUT_DFA"
echo ""

INNER=$(mktemp /tmp/re_conv_XXXXXX.sh)
cat > "$INNER" << 'INNER_EOF'
#!/usr/bin/env bash
REGEX="$1"
OUTPUT_NFA="$2"
OUTPUT_DFA="$3"
NFAE_TMP=$(mktemp /tmp/nfae_XXXXXX.yaml)

cabal run lab1-part2 -- "$REGEX" "$NFAE_TMP" &&
cabal run lab1       -- "$NFAE_TMP" "$OUTPUT_NFA" "$OUTPUT_DFA"

rm -f "$NFAE_TMP"
INNER_EOF

nix develop --command bash "$INNER" "$REGEX" "$OUTPUT_NFA" "$OUTPUT_DFA"
STATUS=$?

rm -f "$INNER"
exit "$STATUS"
