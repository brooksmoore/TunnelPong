#!/usr/bin/env bash
# Build Tunnel Pong for Mac Catalyst and launch it (no iOS Simulator).
# Usage: ./bin/play-mac.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/TunnelPong.xcodeproj"
SCHEME="TunnelPong"

# Prefer Xcode 26.1 if present (matches project docs).
if [[ -d /Applications/Xcode-26.1.app ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-26.1.app/Contents/Developer
fi

# Build off Desktop — Desktop/iCloud File Provider xattrs break codesign.
DERIVED="${TMPDIR:-/tmp}/tunnelpong-derived"
DEST="platform=macOS,variant=Mac Catalyst,arch=$(uname -m)"

echo "→ Building Tunnel Pong (Mac Catalyst)…"
set +e
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "$DEST" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" \
  build
BUILD_RC=$?
set -e

APP="$DERIVED/Build/Products/Debug-maccatalyst/TunnelPong.app"
if [[ ! -d "$APP" ]]; then
  echo "Build failed — no app at $APP (exit $BUILD_RC)"
  exit 1
fi

# If codesign left the app unsigned (Desktop xattrs can still taint), clean + ad-hoc sign.
if ! codesign -v "$APP" 2>/dev/null; then
  echo "→ Fixing signature (strip xattrs)…"
  CLEAN="${TMPDIR:-/tmp}/TunnelPong-clean.app"
  rm -rf "$CLEAN"
  ditto --norsrc --noextattr --noqtn "$APP" "$CLEAN"
  rm -rf "$APP"
  mv "$CLEAN" "$APP"
  codesign --force --sign - --timestamp=none --generate-entitlement-der \
    "$APP/Contents/MacOS/TunnelPong.debug.dylib" 2>/dev/null || true
  codesign --force --sign - --timestamp=none --generate-entitlement-der \
    "$APP/Contents/MacOS/__preview.dylib" 2>/dev/null || true
  codesign --force --sign - --timestamp=none --generate-entitlement-der "$APP"
fi

# Restart if already running
pkill -x TunnelPong 2>/dev/null || true
sleep 0.3

echo "→ Launching: $APP"
open "$APP"
echo "Mac play: move the mouse — paddle follows (no click held)."
echo "Click still starts a run / pauses / menus."
