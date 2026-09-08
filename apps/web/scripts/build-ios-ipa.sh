#!/usr/bin/env bash
set -euo pipefail

export_method="${IOS_EXPORT_METHOD:-release-testing}"
signing_mode="${IOS_SIGNING_MODE:-unsigned}"
case "$signing_mode" in
  unsigned|signed) ;;
  *)
    echo "IOS_SIGNING_MODE must be unsigned or signed" >&2
    exit 2
    ;;
esac

if [[ "$signing_mode" == "signed" ]]; then
  : "${IOS_TEAM_ID:?Set IOS_TEAM_ID to the Apple Developer Team ID}"
  : "${IOS_PROVISIONING_PROFILE_NAME:?Set IOS_PROVISIONING_PROFILE_NAME to the installed profile name}"
fi

case "$export_method" in
  app-store-connect)
    signing_certificate="${IOS_SIGNING_CERTIFICATE:-Apple Distribution}"
    ;;
  release-testing)
    signing_certificate="${IOS_SIGNING_CERTIFICATE:-Apple Distribution}"
    ;;
  debugging)
    signing_certificate="${IOS_SIGNING_CERTIFICATE:-Apple Development}"
    ;;
  *)
    echo "IOS_EXPORT_METHOD must be app-store-connect, release-testing, or debugging" >&2
    exit 2
    ;;
esac

project_root="$(cd "$(dirname "$0")/.." && pwd)"
archive_path="$project_root/ios/output/ChengXinYouYou.xcarchive"
export_path="$project_root/ios/output/ipa"
export_options="$(mktemp -t chengxin-youyou-export).plist"
trap 'rm -f "$export_options"' EXIT

web_mode="${IOS_WEB_MODE:-apk}"
case "$web_mode" in
  apk|source) ;;
  *)
    echo "IOS_WEB_MODE must be apk or source" >&2
    exit 2
    ;;
esac

cd "$project_root"
if [[ "${IOS_SKIP_SYNC:-0}" != "1" ]]; then
  pnpm install --frozen-lockfile
  pnpm run "ios:sync:$web_mode"
fi

rm -rf "$archive_path" "$export_path"
mkdir -p "$export_path"

if [[ "$signing_mode" == "signed" ]]; then
  cat >"$export_options" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key><string>export</string>
  <key>method</key><string>${export_method}</string>
  <key>signingStyle</key><string>manual</string>
  <key>teamID</key><string>${IOS_TEAM_ID}</string>
  <key>signingCertificate</key><string>${signing_certificate}</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>org.dpdns.fanxiaogao05.chengxinyouyou</key>
    <string>${IOS_PROVISIONING_PROFILE_NAME}</string>
  </dict>
  <key>stripSwiftSymbols</key><true/>
</dict>
</plist>
PLIST

  xcodebuild \
    -project ios/App/App.xcodeproj \
    -scheme App \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$archive_path" \
    DEVELOPMENT_TEAM="$IOS_TEAM_ID" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$signing_certificate" \
    PROVISIONING_PROFILE_SPECIFIER="$IOS_PROVISIONING_PROFILE_NAME" \
    clean archive

  xcodebuild \
    -exportArchive \
    -archivePath "$archive_path" \
    -exportPath "$export_path" \
    -exportOptionsPlist "$export_options"
else
  xcodebuild \
    -project ios/App/App.xcodeproj \
    -scheme App \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$archive_path" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY='' \
    DEVELOPMENT_TEAM='' \
    clean archive

  mkdir -p "$export_path/Payload"
  cp -R "$archive_path/Products/Applications/App.app" "$export_path/Payload/App.app"
  (cd "$export_path" && zip -qry "ChengXinYouYou-unsigned.ipa" Payload)
  rm -rf "$export_path/Payload"
fi

echo "IPA exported to $export_path"
