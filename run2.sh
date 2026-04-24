#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

REGEX=${1:?"Uso: ./run2.sh '<regex>' [output.yaml]"}
OUTPUT=${2:-output.yaml}
NFA_TMP=$(mktemp /tmp/nfa_XXXXXX.yaml)

echo "🔤 Regex : $REGEX"
echo "📤 Output: $OUTPUT"

nix develop --command bash -c "
  cabal run lab1-part2 -- '$REGEX' '$NFA_TMP' &&
  cabal run lab1 -- '$NFA_TMP' '$OUTPUT'
"

rm -f "$NFA_TMP"
