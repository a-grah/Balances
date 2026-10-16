#!/usr/bin/env bash
#
# release.sh — Build, sign, notarize, staple, and package Balances into a
# distributable DMG for the web store.
#
# Produces a Developer ID-signed, hardened-runtime, NOTARIZED + STAPLED:
#   - dist/Balances.app        (standalone, stapled — zip it if you want)
#   - dist/Balances-<ver>.dmg  (drag-to-Applications, stapled — the deliverable)
#
# Prerequisites (one-time):
#   - A "Developer ID Application" certificate in your login keychain.
#   - A stored notarytool credential profile (see NOTARY_PROFILE below), created with:
#       xcrun notarytool store-credentials "balances-notary" \
#         --apple-id <id> --team-id UVNB86SP95 --password <app-specific-pw>
#     or, instead of a profile, an App Store Connect API key passed through
#     NOTARY_KEY_PATH (.p8 file), NOTARY_KEY_ID and NOTARY_ISSUER_ID — this is
#     how CI (.github/workflows/release.yml) notarizes.
#
# Usage:
#   scripts/release.sh                # full build → notarize → staple → dmg
#   SKIP_NOTARIZE=1 scripts/release.sh  # build + sign only (local smoke test)
#
set -euo pipefail

# ---- Config ----------------------------------------------------------------
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Blue Pill Software Ltd. (UVNB86SP95)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-balances-notary}"
SCHEME="Balances"
PROJECT="Balances.xcodeproj"
ENTITLEMENTS="Balances/Balances.entitlements"

if [[ -n "${NOTARY_KEY_PATH:-}" ]]; then
  NOTARY_AUTH=(--key "$NOTARY_KEY_PATH" --key-id "${NOTARY_KEY_ID:?}" --issuer "${NOTARY_ISSUER_ID:?}")
else
  NOTARY_AUTH=(--keychain-profile "$NOTARY_PROFILE")
fi

# ---- Paths -----------------------------------------------------------------
cd "$(dirname "$0")/.."          # repo root
ROOT="$(pwd)"
DIST="$ROOT/dist"
STAGE="$DIST/dmg_stage"

# Marketing version straight from the build settings, so the DMG name tracks it.
VERSION="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -showBuildSettings 2>/dev/null | awk -F' = ' '/ MARKETING_VERSION /{print $2; exit}')"
: "${VERSION:?could not read MARKETING_VERSION}"

APP="$DIST/Balances.app"
DMG="$DIST/Balances-$VERSION.dmg"

echo "==> Balances release $VERSION"
rm -rf "$DIST"
mkdir -p "$DIST"

# ---- 1. Build (Developer ID + hardened runtime) ----------------------------
# CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO is set in the Release config so Xcode
# does not inject get-task-allow (which notarization rejects).
echo "==> Building Release (universal, signed)…"
DERIVED="$DIST/DerivedData"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -sdk macosx ONLY_ACTIVE_ARCH=NO \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM=UVNB86SP95 \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  build >/dev/null
ditto "$DERIVED/Build/Products/Release/Balances.app" "$APP"

# ---- 2. Re-sign with our entitlements only (belt-and-suspenders) -----------
# Guarantees no stray entitlements and a secure timestamp, regardless of how
# Xcode signed during the build.
echo "==> Signing (hardened runtime, secure timestamp)…"
# Sparkle's helpers first, inside out, as Sparkle's documentation describes.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
sign() { codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$@"; }
sign "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
sign "$SPARKLE/Versions/B/Autoupdate"
sign "$SPARKLE/Versions/B/Updater.app"
sign "$SPARKLE"
codesign --force --options runtime --timestamp \
  --sign "$SIGN_IDENTITY" \
  --entitlements "$ENTITLEMENTS" \
  "$APP"

echo "==> Verifying signature…"
codesign --verify --deep --strict --verbose=2 "$APP"
if codesign -d --entitlements - "$APP" 2>&1 | grep -q "get-task-allow"; then
  echo "ERROR: get-task-allow present after signing — would fail notarization." >&2
  exit 1
fi

if [[ "${SKIP_NOTARIZE:-0}" == "1" ]]; then
  echo "==> SKIP_NOTARIZE=1 set; stopping after signing. App at: $APP"
  exit 0
fi

# ---- 3. Notarize + staple the app ------------------------------------------
echo "==> Notarizing app…"
ZIP="$DIST/Balances-notarize.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" "${NOTARY_AUTH[@]}" --wait
rm -f "$ZIP"
echo "==> Stapling app…"
xcrun stapler staple "$APP"

# ---- 4. Build, sign, notarize, staple the DMG ------------------------------
echo "==> Building DMG…"
rm -rf "$STAGE"; mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Balances.app"
rm -f "$DMG"
create-dmg \
  --volname "Balances $VERSION" \
  --background "scripts/dmg-background.tiff" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 128 \
  --icon "Balances.app" 165 190 \
  --hide-extension "Balances.app" \
  --app-drop-link 495 190 \
  "$DMG" \
  "$STAGE/" >/dev/null
rm -rf "$STAGE"

echo "==> Signing DMG…"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"

echo "==> Notarizing DMG…"
xcrun notarytool submit "$DMG" "${NOTARY_AUTH[@]}" --wait
echo "==> Stapling DMG…"
xcrun stapler staple "$DMG"

# ---- 5. Final verification -------------------------------------------------
echo "==> Gatekeeper assessment:"
spctl -a -t open --context context:primary-signature -vv "$DMG"
rm -rf "$DERIVED"

echo
echo "✅ Done."
echo "   App:  $APP"
echo "   DMG:  $DMG  ($(du -h "$DMG" | cut -f1))"
shasum -a 256 "$DMG"
