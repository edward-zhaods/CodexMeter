#!/bin/zsh
# Build "AIusage.app" with only the Command Line Tools installed (no Xcode.app).
#
#   ./scripts/build-clt.sh
#   CONFIGURATION=debug ./scripts/build-clt.sh
#   OUT_DIR=/tmp/aiusage ./scripts/build-clt.sh
#
# The asset catalog needs actool, which ships with Xcode only. Without Xcode the
# script reuses the Assets.car / AppIcon.icns compiled by an earlier Xcode build.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT_DIR="${OUT_DIR:-build/clt}"
APP="$OUT_DIR/AIusage.app"
CONFIGURATION="${CONFIGURATION:-release}"
ARCH="${ARCH:-$(uname -m)}"
SDK="$(xcrun --show-sdk-path)"
PBXPROJ="AIusage.xcodeproj/project.pbxproj"
VERSION="$(grep -m1 'MARKETING_VERSION' "$PBXPROJ" | sed -E 's/.*= *([^;]+);.*/\1/')"
BUILD_NUMBER="$(grep -m1 'CURRENT_PROJECT_VERSION' "$PBXPROJ" | sed -E 's/.*= *([^;]+);.*/\1/')"

OPT_FLAGS=(-O)
if [[ "$CONFIGURATION" == "debug" ]]; then
  OPT_FLAGS=(-Onone -g)
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

SOURCES=(${(f)"$(find AIusage -name '*.swift' | sort)"})
swiftc \
  -swift-version 6 \
  -parse-as-library \
  -target "$ARCH-apple-macos14.0" \
  -sdk "$SDK" \
  "${OPT_FLAGS[@]}" \
  -module-name AIusage \
  -o "$APP/Contents/MacOS/AIusage" \
  "${SOURCES[@]}"

sed \
  -e "s/\$(EXECUTABLE_NAME)/AIusage/g" \
  -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/com.edward.CodexMeter/g" \
  -e "s/\$(DEVELOPMENT_LANGUAGE)/en/g" \
  -e "s/\$(MARKETING_VERSION)/$VERSION/g" \
  -e "s/\$(CURRENT_PROJECT_VERSION)/$BUILD_NUMBER/g" \
  AIusage/Info.plist > "$APP/Contents/Info.plist"
plutil -replace CFBundleIconFile -string AppIcon "$APP/Contents/Info.plist"
plutil -replace CFBundleIconName -string AppIcon "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

if actool --version >/dev/null 2>&1; then
  actool AIusage/Assets.xcassets \
    --compile "$APP/Contents/Resources" \
    --platform macosx \
    --minimum-deployment-target 14.0 \
    --app-icon AppIcon \
    --output-partial-info-plist /dev/null >/dev/null
else
  ICON_SOURCES=(
    "build/DerivedData/Build/Products/Release/AIusage.app/Contents/Resources"
    "build/DerivedData/Build/Products/Release/Codex Meter.app/Contents/Resources"
    "AIusage.app/Contents/Resources"
    "$HOME/Desktop/AIusage.app/Contents/Resources"
    "$HOME/Desktop/Codex Meter.app/Contents/Resources"
  )
  copied=0
  for dir in "${ICON_SOURCES[@]}"; do
    if [[ -f "$dir/Assets.car" ]]; then
      cp "$dir/Assets.car" "$APP/Contents/Resources/"
      if [[ -f "$dir/AppIcon.icns" ]]; then
        cp "$dir/AppIcon.icns" "$APP/Contents/Resources/"
      fi
      copied=1
      break
    fi
  done
  if [[ $copied -eq 0 ]]; then
    echo "warning: no compiled asset catalog found; the app will show a generic icon" >&2
  fi
fi

codesign --force --deep --sign - --options runtime "$APP"
echo "Built $APP (version $VERSION, $CONFIGURATION, $ARCH)"
