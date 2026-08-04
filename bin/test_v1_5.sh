#!/bin/bash
# CyberPong v1.5 logic tests — compiled against the REAL shipping source.
#
# Links TunnelPong/Config.swift and TunnelPong/Projection.swift directly, so
# there is no mirrored copy of the logic and no way for the test to drift from
# the app. If Projection.swift stops compiling, this fails loudly rather than
# testing a stale copy.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT="$(mktemp -d)/cyberpong_v1_5_tests"

swiftc -O \
    TunnelPong/Config.swift \
    TunnelPong/Projection.swift \
    bin/v1_5_tests/main.swift \
    -o "$OUT"

"$OUT"
