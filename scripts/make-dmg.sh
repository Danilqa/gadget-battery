#!/bin/zsh
# Builds a notarized Release DMG: scripts/make-dmg.sh
# Needs Xcode signed in to team 5JJ2HBXA25; Xcode signs with its cloud-managed Developer ID certificate.
set -euo pipefail

cd "$(dirname "$0")/.."
version=$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)
out=build/release-$version-$(date +%Y%m%d%H%M%S)
archive=$out/GadgetBattery.xcarchive
dmg=$out/Gadget-Battery.dmg
mkdir -p $out/stage

xcodegen generate --quiet
xcodebuild archive -project GadgetBattery.xcodeproj -scheme GadgetBattery -configuration Release \
  -destination "generic/platform=macOS" -archivePath $archive -derivedDataPath build/derived -quiet

cat > $out/ExportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>destination</key><string>upload</string>
  <key>signingStyle</key><string>automatic</string>
  <key>teamID</key><string>5JJ2HBXA25</string>
</dict>
</plist>
EOF
xcodebuild -exportArchive -archivePath $archive -exportOptionsPlist $out/ExportOptions.plist \
  -exportPath $out/upload -allowProvisioningUpdates

echo "Waiting for notarization…"
for attempt in {1..40}; do
  xcodebuild -exportNotarizedApp -archivePath $archive -exportPath $out/notarized >$out/notarized.log 2>&1 && break
  (( attempt == 40 )) && { cat $out/notarized.log; exit 1; }
  sleep 30
done

cp -R "$out/notarized/Gadget Battery.app" $out/stage/
ln -s /Applications $out/stage/Applications
hdiutil create -volname "Gadget Battery" -srcfolder $out/stage -ov -format UDZO $dmg >/dev/null
xcrun stapler validate "$out/stage/Gadget Battery.app"
echo $dmg
