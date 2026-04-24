#!/usr/bin/env bash
# run2.sh — Parte 2: converte uma Expressão Regular diretamente em DFA.
#            Pipeline: Regex → NFAε (Thompson) → NFA → DFA (subconjuntos + minimização)
#
# Uso:
#   ./run2.sh "<regex>" [output.yaml]
#
# Exemplos:
#   ./run2.sh "(a|b)*abb"
#   ./run2.sh "a*b+c?" output/resultado.yaml
#
# Operadores suportados:
#   Concatenação : justaposição  (ab)
#   União        : |             (a|b)
#   Kleene       : *             (a*)
#   Uma ou mais  : +             (a+)
#   Opcional     : ?             (a?)
set -e

cd "$(dirname "$0")"

REGEX=${1:?"Uso: ./run2.sh '<regex>' [output.yaml]"}
OUTPUT=${2:-output/result.yaml}
NFA_TMP=$(mktemp /tmp/nfa_XXXXXX.yaml)

echo "🔤 Regex : $REGEX"
echo "📤 Output: $OUTPUT"
echo ""

nix develop --command bash -c "
  cabal run lab1-part2 -- '$REGEX' '$NFA_TMP' &&
  cabal run lab1       -- '$NFA_TMP' '$OUTPUT'
"

rm -f "$NFA_TMP"
