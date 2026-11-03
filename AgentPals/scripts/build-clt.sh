#!/bin/zsh
# Build AgentPals.app with the Swift command-line tools. No asset catalog.
#
#   ./scripts/build-clt.sh
#   CONFIGURATION=debug ./scripts/build-clt.sh
#   OUT_DIR=/tmp/agentpals ./scripts/build-clt.sh
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
printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --deep --sign - --options runtime "$APP"
echo "Built $APP ($CONFIGURATION, $ARCH)"
