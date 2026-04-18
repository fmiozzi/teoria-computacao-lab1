#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

INPUT=${1:-input.yaml}
OUTPUT=${2:-output.yaml}

echo "📥 Input: $INPUT"
echo "📤 Output: $OUTPUT"

nix develop --command bash -c "cabal run lab1 -- $INPUT $OUTPUT"