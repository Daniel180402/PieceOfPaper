#!/usr/bin/env bash
# Builds "Piece of Paper.app" in ./build.
#
#   Scripts/build-app.sh             release build
#   Scripts/build-app.sh --debug     debug build
#   Scripts/build-app.sh --install   release build, then copy to /Applications
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG=release
INSTALL=false
for arg in "$@"; do
    case "$arg" in
        --debug) CONFIG=debug ;;
        --install) INSTALL=true ;;
        *) echo "Opzione sconosciuta: $arg" >&2; exit 1 ;;
    esac
done

VERSION=$(sed -n 's/.*public static let version = "\(.*\)".*/\1/p' Sources/PaperKit/PaperKit.swift)
BUILD=$(git rev-list --count HEAD 2>/dev/null || echo 1)
APP="build/Piece of Paper.app"

echo "→ swift build -c $CONFIG"
swift build -c "$CONFIG"
BIN_DIR=$(swift build -c "$CONFIG" --show-bin-path)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/PieceOfPaper" "$APP/Contents/MacOS/PieceOfPaper"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"
if [[ -f Resources/AppIcon.icns ]]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc signature, enough to run the app on this Mac.
codesign --force --sign - "$APP" >/dev/null

echo "✓ $APP (versione $VERSION, build $BUILD)"

if $INSTALL; then
    rm -rf "/Applications/Piece of Paper.app"
    cp -R "$APP" /Applications/
    echo "✓ Installata in /Applications"
fi
