#!/usr/bin/env bash
# run2.sh — Parte 2: converte uma Expressão Regular diretamente em DFA mínimo.
#            Pipeline completo:
#              Regex → NFAε (Thompson/lab1-part2)
#                    → NFA  (removeEpsilon/lab1)   → output_nfa.yaml
#                    → DFA mínimo (subconjuntos + minimização/lab1) → output_dfa.yaml
#
# Uso:
#   ./run2.sh "<regex>" [output_nfa.yaml] [output_dfa.yaml]
#
# Exemplos:
#   ./run2.sh "(a|b)*abb"
#   ./run2.sh "a*b+c?" output/resultado_nfa.yaml output/resultado_dfa.yaml
#
# Operadores suportados:
#   Concatenação : justaposição  (ab)
#   União        : |             (a|b)
#   Kleene       : *             (a*)
#   Uma ou mais  : +             (a+)
#   Opcional     : ?             (a?)
set -e

cd "$(dirname "$0")"

REGEX=${1:?"Uso: ./run2.sh '<regex>' [output_nfa.yaml] [output_dfa.yaml]"}
OUTPUT_NFA=${2:-output/result_nfa.yaml}
OUTPUT_DFA=${3:-output/result_dfa.yaml}
NFAE_TMP=$(mktemp /tmp/nfae_XXXXXX.yaml)

echo "🔤 Regex      : $REGEX"
echo "📤 Output NFA : $OUTPUT_NFA"
echo "📤 Output DFA : $OUTPUT_DFA"
echo ""

nix develop --command bash -c "
  cabal run lab1-part2 -- '$REGEX' '$NFAE_TMP' &&
  cabal run lab1       -- '$NFAE_TMP' '$OUTPUT_NFA' '$OUTPUT_DFA'
"

rm -f "$NFAE_TMP"
