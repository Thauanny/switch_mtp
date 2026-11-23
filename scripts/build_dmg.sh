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
VOLNAME="Switch MTP $VERSION"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# Fundo da janela (1x + 2x num único .tiff, para telas Retina).
mkdir -p "$STAGE/.background"
swift scripts/make_dmg_background.swift "$STAGE/.background"
tiffutil -cathidpicheck "$STAGE/.background/background.png" "$STAGE/.background/background@2x.png" \
  -out "$STAGE/.background/background.tiff" >/dev/null 2>&1
rm "$STAGE/.background/"*.png

mkdir -p dist
DMG="dist/Switch-MTP-$VERSION-$ARCH.dmg"
RW="$STAGE.rw.dmg"
rm -f "$DMG" "$RW"
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGE" -ov -format UDRW -fs HFS+ "$RW" >/dev/null

# Monta a imagem gravável e arruma a janela pelo Finder: tamanho fixo, ícones grandes nas
# posições da seta do fundo, sem barras. Se o Finder não responder (ex.: sem sessão gráfica),
# o .dmg sai mesmo assim, só que com a janela padrão.
[ -d "/Volumes/$VOLNAME" ] && hdiutil detach "/Volumes/$VOLNAME" -force >/dev/null || true
ATTACH="$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | grep Apple_HFS)"
DEV="$(echo "$ATTACH" | awk '{print $1}')"
MNT="$(echo "$ATTACH" | grep -o '/Volumes/.*' | sed -E 's/[[:space:]]+$//')"
if ! osascript >/dev/null <<EOF
tell application "Finder"
  tell disk "$VOLNAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 840, 548}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 128
    set text size of opts to 13
    set background picture of opts to file ".background:background.tiff"
    set position of item "Switch MTP.app" of container window to {160, 190}
    set position of item "Applications" of container window to {480, 190}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF
then
  echo "Aviso: não foi possível ajustar a janela do .dmg pelo Finder; usando a aparência padrão." >&2
fi
# Ícone do volume (o hdiutil descarta o .VolumeIcon.icns da pasta de origem e o Finder o
# remove ao gravar o layout, por isso ele entra por último).
cp "$APP/Contents/Resources/AppIcon.icns" "$MNT/.VolumeIcon.icns"
SetFile -a C "$MNT" 2>/dev/null || true
sync
hdiutil detach "$DEV" -force >/dev/null
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$RW"

MINOS="$(otool -l "$APP/Contents/Frameworks/libmtp.9.dylib" | awk '/minos/{print $2; exit}')"
echo
echo "Pronto: $DMG ($(du -h "$DMG" | cut -f1)) · abre em Macs $ARCH com macOS $MINOS ou mais novo"
