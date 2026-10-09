#!/bin/bash
# Builds, signs, notarizes and packages a release, then regenerates the Sparkle feed.
# Nothing is published: it ends by printing the GitHub steps that are left.
#
#   ./scripts/release.sh
#
# Before running:
#   - set MARKETING_VERSION in project.yml to the Patchy release this build supports
#   - raise CURRENT_PROJECT_VERSION in project.yml
#   - write docs/release-notes/<version>.md
#
# Needs: Developer ID Application certificate in the keychain, Sparkle's EdDSA private key in the
# keychain, and a notarytool keychain profile (NOTARY_PROFILE, default "shrinkerpro-notary").
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

IDENTITY="Developer ID Application: Eight-Seven Inc. (LY424U3HLD)"
KEYCHAIN_PROFILE="${NOTARY_PROFILE:-shrinkerpro-notary}"
GITHUB_REPO="jeso87/Patchy-UI"
FEED_URL="https://jeso87.github.io/Patchy-UI/appcast.xml"
DERIVED="build"
ARCHIVE="build/PatchyUI.xcarchive"
EXPORT="build/export"
APP="$EXPORT/Patchy UI.app"

echo "==> testing PatchyKit"
( cd PatchyKit && swift test 2>&1 | tail -1 )

echo "==> regenerating project"
xcodegen generate

echo "==> archiving"
rm -rf "$ARCHIVE" "$EXPORT"
xcodebuild archive \
  -project "Patchy UI.xcodeproj" \
  -scheme "Patchy UI" \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  -archivePath "$ARCHIVE" \
  -destination 'generic/platform=macOS' \
  | tail -3

echo "==> exporting with Developer ID"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT" \
  -exportOptionsPlist scripts/ExportOptions.plist | tail -3

echo "==> verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Contents/Info.plist")
RELEASE_TAG="v$VERSION"

# The version is the promise: Patchy UI x.y.z supports Patchy x.y.z. Release only what was
# built and tested against that Patchy.
SUPPORTED=$(echo "$VERSION" | cut -d. -f1-3)
INSTALLED=$(patchy version 2>/dev/null | awk '{print $2}')
echo "==> version match: Patchy UI $VERSION supports Patchy $SUPPORTED (installed: ${INSTALLED:-none})"
if [ "$INSTALLED" != "$SUPPORTED" ] && [ -z "${ALLOW_VERSION_MISMATCH:-}" ]; then
  echo "FAIL  this Mac has Patchy ${INSTALLED:-none}, but the release claims to support $SUPPORTED." >&2
  echo "      Upgrade Patchy and re-test, or fix MARKETING_VERSION in project.yml." >&2
  echo "      (ALLOW_VERSION_MISMATCH=1 overrides this.)" >&2
  exit 1
fi

RELEASE_NOTES="docs/release-notes/$VERSION.md"
[ -f "$RELEASE_NOTES" ] || {
  echo "FAIL  no release notes at $RELEASE_NOTES" >&2
  echo "      Sparkle shows these to every user before they install $VERSION." >&2
  exit 1
}

DMG="dist/PatchyUI-$VERSION.dmg"
STABLE_DMG="dist/PatchyUI.dmg"
STAGE="build/dmg-stage"
echo "==> building $DMG"
mkdir -p dist
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp LICENSE "$STAGE/"
hdiutil create -volname "Patchy UI" -srcfolder "$STAGE" -ov -format ULFO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "==> signing DMG"
codesign --force --sign "$IDENTITY" --timestamp "$DMG"

echo "==> notarizing (this takes a few minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$KEYCHAIN_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"
cp "$DMG" "$STABLE_DMG"

# Sparkle's command-line tools arrive with the Swift package.
SPARKLE_BIN="$DERIVED/SourcePackages/artifacts/sparkle/Sparkle/bin"
[ -x "$SPARKLE_BIN/generate_appcast" ] || {
  echo "FAIL  Sparkle tools not found at $SPARKLE_BIN" >&2
  exit 1
}

echo "==> generating appcast"
APPCAST_STAGE="build/appcast-stage"
rm -rf "$APPCAST_STAGE"
mkdir -p "$APPCAST_STAGE"
cp "$DMG" "$APPCAST_STAGE/"
cp "$RELEASE_NOTES" "$APPCAST_STAGE/$(basename "$DMG" .dmg).md"
[ -f appcast.xml ] && cp appcast.xml "$APPCAST_STAGE/appcast.xml"

if [ -f "$APPCAST_STAGE/appcast.xml" ]; then
  PUBLISHED_BUILD=$(grep -o '<sparkle:version>[0-9]*</sparkle:version>' "$APPCAST_STAGE/appcast.xml" \
    | grep -o '[0-9]*' | sort -n | tail -1)
  if [ -n "${PUBLISHED_BUILD:-}" ] && [ "$BUILD_NUMBER" -le "$PUBLISHED_BUILD" ]; then
    echo "FAIL  CURRENT_PROJECT_VERSION is $BUILD_NUMBER, but the feed already has build $PUBLISHED_BUILD." >&2
    echo "      Sparkle compares this number, not $VERSION, so existing installs would never" >&2
    echo "      be offered this release. Raise CURRENT_PROJECT_VERSION in project.yml." >&2
    exit 1
  fi
fi

"$SPARKLE_BIN/generate_appcast" \
  --embed-release-notes \
  --download-url-prefix "https://github.com/$GITHUB_REPO/releases/download/$RELEASE_TAG/" \
  "$APPCAST_STAGE"
cp "$APPCAST_STAGE/appcast.xml" appcast.xml
rm -rf "$APPCAST_STAGE"

echo
echo "=================================================================="
echo "Patchy UI $VERSION (build $BUILD_NUMBER) is built, notarized and in the"
echo "local update feed. Nothing has been published yet."
echo
echo "To publish:"
echo "  1. Create a GitHub Release tagged $RELEASE_TAG:"
echo "       https://github.com/$GITHUB_REPO/releases/new?tag=$RELEASE_TAG"
echo "  2. Upload both files as release assets, names unchanged:"
echo "       $DMG"
echo "       $STABLE_DMG      (same bytes; the README download button)"
echo "  3. Commit and push the feed so GitHub Pages serves it:"
echo "       git add appcast.xml && git commit -m \"Publish $RELEASE_TAG to the update feed\" && git push"
echo
echo "  Feed URL (must match SUFeedURL in project.yml): $FEED_URL"
echo "=================================================================="
