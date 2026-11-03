#!/bin/zsh
# Build AgentPals.app with the Swift command-line tools. No asset catalog.
#
#   ./scripts/build-clt.sh
#   CONFIGURATION=debug ./scripts/build-clt.sh
#   OUT_DIR=/tmp/agentpals ./scripts/build-clt.sh
#   INSTALL=0 ./scripts/build-clt.sh
#
# INSTALL defaults to 1 and copies the app to /Applications/AgentPals.app.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT_DIR="${OUT_DIR:-build/clt}"
APP="$OUT_DIR/AgentPals.app"
CONFIGURATION="${CONFIGURATION:-release}"
ARCH="${ARCH:-$(uname -m)}"
SDK="$(xcrun --show-sdk-path)"

OPT_FLAGS=(-O)
if [[ "$CONFIGURATION" == "debug" ]]; then
  OPT_FLAGS=(-Onone -g)
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

SOURCES=(${(f)"$(find . -name '*.swift' -not -path './build/*' | sort)"})
swiftc \
  -swift-version 6 \
  -parse-as-library \
  -target "$ARCH-apple-macos14.0" \
  -sdk "$SDK" \
  "${OPT_FLAGS[@]}" \
  -module-name AgentPals \
  -o "$APP/Contents/MacOS/AgentPals" \
  "${SOURCES[@]}"

cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --deep --sign - --options runtime "$APP"
echo "Built $APP ($CONFIGURATION, $ARCH)"

if [[ "${INSTALL:-1}" == "1" ]]; then
  DEST="/Applications/AgentPals.app"
  if [[ ! -w "/Applications" ]]; then
    echo "无法写入 /Applications。把 $APP 拖进「应用程序」文件夹后再双击。" >&2
    exit 1
  fi
  # Quit a copy left over from an earlier build so two menu-bar pets do not stack.
  killall AgentPals 2>/dev/null || true
  rm -rf "$DEST"
  ditto "$APP" "$DEST"
  xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
  echo "Installed $DEST"
  echo "在「应用程序」里双击 AgentPals 打开。点菜单栏小人，选「退出」关闭。"
fi
