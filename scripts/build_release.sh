#!/usr/bin/env bash
# Gera "Switch MTP.app" em modo release com libmtp + libusb embutidas,
# para rodar em Macs sem Homebrew. Uso: ./scripts/build_release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

BREW="$(brew --prefix)"
MTP="$BREW/opt/libmtp/lib/libmtp.9.dylib"
USB="$BREW/opt/libusb/lib/libusb-1.0.0.dylib"
[[ -f "$MTP" ]] || { echo "Instale a libmtp: brew install libmtp"; exit 1; }

flutter build macos --release

APP="build/macos/Build/Products/Release/Switch MTP.app"
FW="$APP/Contents/Frameworks"
mkdir -p "$FW"
install -m 755 "$MTP" "$FW/libmtp.9.dylib"
install -m 755 "$USB" "$FW/libusb-1.0.0.dylib"

install_name_tool -id "@rpath/libusb-1.0.0.dylib" "$FW/libusb-1.0.0.dylib"
install_name_tool -id "@rpath/libmtp.9.dylib" "$FW/libmtp.9.dylib"
install_name_tool -change "$(otool -L "$MTP" | awk '/libusb/{print $1}')" \
  "@loader_path/libusb-1.0.0.dylib" "$FW/libmtp.9.dylib"

# Assinatura ad-hoc (necessária no Apple Silicon após alterar os binários).
codesign --force --sign - "$FW/libusb-1.0.0.dylib" "$FW/libmtp.9.dylib"
codesign --force --deep --sign - \
  --entitlements macos/Runner/Release.entitlements "$APP"

echo
echo "Pronto: $APP"
otool -L "$FW/libmtp.9.dylib" | grep -E "usb|mtp"
