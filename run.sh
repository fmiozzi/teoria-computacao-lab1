#!/usr/bin/env bash
cd "$(dirname "$0")"
nix develop --command runhaskell main.hs
