#!/usr/bin/env bash
# run.sh — Parte 1: converte um autômato NFAε/NFA/DFA.
#           Pipeline (conforme tipo de entrada):
#             NFAε → NFA (removeEpsilon) → DFA mínimo (subconjuntos + minimização)
#             NFA  →                       DFA mínimo (subconjuntos + minimização)
#             DFA  →                       DFA mínimo (minimização)
#
# Uso:
#   ./run.sh [input.yaml] [output_nfa.yaml] [output_dfa.yaml]
#
# Exemplos:
#   ./run.sh                                                        # usa defaults
#   ./run.sh input/nfae_simple.yaml output/simple_nfa.yaml output/simple_dfa.yaml
set -e

cd "$(dirname "$0")"

INPUT=${1:-input/nfae_simple.yaml}
OUTPUT_NFA=${2:-output/result_nfa.yaml}
OUTPUT_DFA=${3:-output/result_dfa.yaml}

echo "📥 Input      : $INPUT"
echo "📤 Output NFA : $OUTPUT_NFA"
echo "📤 Output DFA : $OUTPUT_DFA"
echo ""

nix develop --command bash -c "cabal run lab1 -- '$INPUT' '$OUTPUT_NFA' '$OUTPUT_DFA'"
