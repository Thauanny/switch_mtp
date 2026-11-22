#!/usr/bin/env bash
# Gera o instalador .dmg do Switch MTP (app + atalho para Aplicativos).
#
# Uso: ./scripts/build_dmg.sh [versão]
#   sem versão, usa a do pubspec.yaml
#   resultado: dist/Switch-MTP-<versão>-<apple-silicon|intel>.dmg
#
# Requer: Flutter, Xcode e `brew install libmtp`. O .dmg serve para Macs com o mesmo
# processador do Mac que o gerou (a libmtp do Homebrew é de uma arquitetura só).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-$(grep -E '^version:' pubspec.yaml | sed -E 's/version: *([^+]*).*/\1/')}"
case "$(uname -m)" in
  arm64) ARCH="apple-silicon" ;;
  *) ARCH="intel" ;;
esac

./scripts/build_release.sh "$VERSION"

APP="build/macos/Build/Products/Release/Switch MTP.app"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

mkdir -p dist
DMG="dist/Switch-MTP-$VERSION-$ARCH.dmg"
rm -f "$DMG"
hdiutil create -volname "Switch MTP $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

MINOS="$(otool -l "$APP/Contents/Frameworks/libmtp.9.dylib" | awk '/minos/{print $2; exit}')"
echo
echo "Pronto: $DMG ($(du -h "$DMG" | cut -f1)) · abre em Macs $ARCH com macOS $MINOS ou mais novo"
