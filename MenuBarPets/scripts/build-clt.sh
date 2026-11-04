#!/bin/zsh
# Build MenuBarPets.app with the Command Line Tools (no Xcode.app required).
#
#   ./scripts/build-clt.sh
#   CONFIGURATION=debug ./scripts/build-clt.sh
set -euo pipefail
cd "$(dirname "$0")/.."

OUT_DIR="${OUT_DIR:-build/clt}"
APP="$OUT_DIR/MenuBarPets.app"
CONFIGURATION="${CONFIGURATION:-release}"
ARCH="${ARCH:-$(uname -m)}"
SDK="$(xcrun --show-sdk-path)"

OPT_FLAGS=(-O)
if [[ "$CONFIGURATION" == "debug" ]]; then
  OPT_FLAGS=(-Onone -g)
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp -R Art "$APP/Contents/Resources/Art"

SOURCES=(${(f)"$(find App MenuBar Pets -name '*.swift' | sort)"})
swiftc \
  -swift-version 6 \
  -parse-as-library \
  -target "$ARCH-apple-macos14.0" \
  -sdk "$SDK" \
  "${OPT_FLAGS[@]}" \
  -module-name MenuBarPets \
  -o "$APP/Contents/MacOS/MenuBarPets" \
  "${SOURCES[@]}"

sed \
  -e "s/\$(EXECUTABLE_NAME)/MenuBarPets/g" \
  -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/com.edward.MenuBarPets/g" \
  -e "s/\$(DEVELOPMENT_LANGUAGE)/en/g" \
  -e "s/\$(MARKETING_VERSION)/0.1.0/g" \
  -e "s/\$(CURRENT_PROJECT_VERSION)/1/g" \
  Info.plist > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

codesign --force --deep --sign - --options runtime "$APP"
echo "Built $APP ($CONFIGURATION, $ARCH)"
