#!/usr/bin/env bash
#
# Build Reticle in Release, ad-hoc sign it, and package a drag-to-Applications DMG.
# Output: dist/Reticle.dmg
#
# Note: the app is NOT notarized (no paid Apple Developer account). On first launch
# users must clear Gatekeeper once — see the README "Download & install" section.

set -euo pipefail

# --- paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$ROOT_DIR/DisplayAlignGuide/DisplayAlignGuide.xcodeproj"
SCHEME="DisplayAlignGuide"
APP_NAME="Reticle"

BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$BUILD_DIR/dmg-staging"
DMG_PATH="$DIST_DIR/${APP_NAME}.dmg"

echo "==> Cleaning previous artifacts"
rm -rf "$BUILD_DIR" "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$DIST_DIR"

echo "==> Building $SCHEME (Release)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="-" \
  DEVELOPMENT_TEAM="" \
  build | tail -n 5

APP_PATH="$BUILD_DIR/Build/Products/Release/${APP_NAME}.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: built app not found at $APP_PATH" >&2
  exit 1
fi

echo "==> Ad-hoc signing $APP_NAME.app"
# Stable ad-hoc signature ("-"): consistent cdhash so the Accessibility grant
# persists across launches; no debug get-task-allow entitlement.
codesign --force --deep --options runtime --sign - "$APP_PATH"
codesign -dv --verbose=2 "$APP_PATH" 2>&1 | sed 's/^/    /' || true

echo "==> Staging DMG contents"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Creating DMG"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "$DMG_PATH" | sed 's/^/    /'

echo ""
echo "✅ Done: $DMG_PATH"
echo "   Upload it to a GitHub Release, e.g.:"
echo "   gh release create vX.Y.Z \"$DMG_PATH\" --title \"Reticle vX.Y.Z\" --notes \"...\""
