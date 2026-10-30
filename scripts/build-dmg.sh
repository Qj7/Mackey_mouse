#!/bin/bash
# Pack Mackey.app into a drag-and-drop .dmg for distribution.
# Re-run for every release after bumping CFBundleShortVersionString in Info.plist.
set -euo pipefail
cd "$(dirname "$0")/.."

SKIP_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    -h|--help)
      cat <<'EOF'
Usage: ./scripts/build-dmg.sh [--skip-build]

  Builds Mackey.app (unless --skip-build) and packs it into
  build/Mackey-<version>.dmg with an Applications shortcut.

  Version is read from Info.plist (CFBundleShortVersionString).
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  ./scripts/build-app.sh --no-install
fi

APP="build/Mackey.app"
if [[ ! -d "$APP" ]]; then
  echo "Missing $APP — run without --skip-build, or build first." >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
VOLUME_NAME="Mackey ${VERSION}"
DMG_NAME="Mackey-${VERSION}.dmg"
STAGE="build/dmg-stage"
FINAL_DMG="build/${DMG_NAME}"

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Mackey.app"
ln -s /Applications "$STAGE/Applications"

IDENTITY="Mackey Self Signed"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
  SIGN="$IDENTITY"
else
  SIGN="-"
fi
codesign --force --sign "$SIGN" --identifier app.mackey.mouse "$STAGE/Mackey.app"

rm -f "$FINAL_DMG" "${FINAL_DMG}.sha256"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$FINAL_DMG"

rm -rf "$STAGE"

shasum -a 256 "$FINAL_DMG" | tee "${FINAL_DMG}.sha256"

echo "Created $FINAL_DMG"
echo "Install: open the DMG and drag Mackey to Applications."
