#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

INSTALL=1
for arg in "$@"; do
  case "$arg" in
    --no-install) INSTALL=0 ;;
    -h|--help)
      echo "Usage: $0 [--no-install]"
      echo "  Builds build/Mackey.app (release)."
      echo "  By default also copies it to /Applications/Mackey.app."
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

swift build -c release

APP="build/Mackey.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Mackey "$APP/Contents/MacOS/Mackey"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/MenuBarIcon.png "$APP/Contents/Resources/MenuBarIcon.png"

# A stable local identity keeps the code-signing designated requirement constant,
# so the Accessibility grant survives rebuilds (adhoc changes identity every build).
IDENTITY="Mackey Self Signed"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
  SIGN="$IDENTITY"
else
  echo "WARNING: '$IDENTITY' not found, falling back to adhoc (grant will not persist)."
  SIGN="-"
fi

codesign --force --sign "$SIGN" --identifier app.mackey.mouse "$APP"

if [[ "$INSTALL" -eq 1 ]]; then
  INSTALL_PATH="/Applications/Mackey.app"
  rm -rf "$INSTALL_PATH"
  cp -R "$APP" "$INSTALL_PATH"
  codesign --force --sign "$SIGN" --identifier app.mackey.mouse "$INSTALL_PATH"
  echo "Installed $INSTALL_PATH"
fi

echo "Built $APP"
