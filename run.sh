#!/usr/bin/env bash
# run.sh — Parte 1: converte um autômato NFAε/NFA em DFA.
#
# Uso:
#   ./run.sh [input.yaml] [output.yaml]
#
# Exemplos:
#   ./run.sh                                        # usa defaults
#   ./run.sh input/nfae_simple.yaml output/dfa.yaml
set -e

cd "$(dirname "$0")"

INPUT=${1:-input/nfae_simple.yaml}
OUTPUT=${2:-output/result.yaml}

echo "📥 Input : $INPUT"
echo "📤 Output: $OUTPUT"
echo ""

nix develop --command bash -c "cabal run lab1 -- '$INPUT' '$OUTPUT'"
