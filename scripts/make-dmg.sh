#!/bin/zsh
# Builds a Release DMG: scripts/make-dmg.sh
# SIGN_IDENTITY defaults to "Developer ID Application" when that certificate is in the keychain.
# NOTARY_PROFILE names a `xcrun notarytool store-credentials` profile; without it the DMG is not notarized.
set -euo pipefail

cd "$(dirname "$0")/.."
version=$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)
out=build/release
archive=$out/GadgetBattery.xcarchive
dmg=$out/Gadget-Battery-$version.dmg

if [[ -z ${SIGN_IDENTITY:-} ]]; then
  if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    SIGN_IDENTITY="Developer ID Application"
  else
    SIGN_IDENTITY="Apple Development"
  fi
fi

rm -rf $out && mkdir -p $out/stage
xcodegen generate --quiet
xcodebuild archive -project GadgetBattery.xcodeproj -scheme GadgetBattery -configuration Release \
  -destination "generic/platform=macOS" -archivePath $archive -derivedDataPath build/derived \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" OTHER_CODE_SIGN_FLAGS=--timestamp -quiet

cp -R "$archive/Products/Applications/Gadget Battery.app" $out/stage/
ln -s /Applications $out/stage/Applications
hdiutil create -volname "Gadget Battery" -srcfolder $out/stage -ov -format UDZO $dmg >/dev/null
codesign --force --timestamp --sign "$SIGN_IDENTITY" $dmg

if [[ -n ${NOTARY_PROFILE:-} ]]; then
  xcrun notarytool submit $dmg --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple $dmg
fi

echo "$dmg (signed with $SIGN_IDENTITY${NOTARY_PROFILE:+, notarized})"
