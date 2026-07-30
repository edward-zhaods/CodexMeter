#!/bin/zsh

set -euo pipefail

project_root="$(cd -- "$(dirname -- "${0:A}")/.." && pwd)"
derived_data_path="${DERIVED_DATA_PATH:-$project_root/build/DerivedData}"
dist_dir="${DIST_DIR:-$project_root/dist}"
app_path="$derived_data_path/Build/Products/Release/Codex Meter.app"

xcodebuild \
  -project "$project_root/CodexMeter.xcodeproj" \
  -scheme "Codex Meter" \
  -configuration Release \
  -derivedDataPath "$derived_data_path" \
  build

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --sign "$SIGN_IDENTITY" \
    "$app_path"
fi

codesign --verify --deep --strict "$app_path"

app_version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app_path/Contents/Info.plist")"
dmg_path="$dist_dir/CodexMeter-$app_version.dmg"
package_tmp="$(mktemp -d "${TMPDIR:-/tmp}/CodexMeterDMG.XXXXXX")"

cleanup() {
  if [[ -n "${package_tmp:-}" && -d "$package_tmp" ]]; then
    rm -rf -- "$package_tmp"
  fi
}
trap cleanup EXIT

ditto "$app_path" "$package_tmp/Codex Meter.app"
ln -s /Applications "$package_tmp/Applications"
mkdir -p "$dist_dir"

hdiutil create \
  -volname "Codex Meter" \
  -srcfolder "$package_tmp" \
  -format UDZO \
  -ov \
  "$dmg_path"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$dmg_path"
  codesign --verify --verbose=2 "$dmg_path"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$dmg_path" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
  xcrun stapler staple "$dmg_path"
  xcrun stapler validate "$dmg_path"
fi

print "Created $dmg_path"
