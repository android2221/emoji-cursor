#!/bin/bash
set -euo pipefail

# EmojiCursor Release Script
# Usage: ./scripts/release.sh [version]
# Example: ./scripts/release.sh 1.0.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/EmojiCursor.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP_NAME="EmojiCursor"
NOTARY_PROFILE="EmojiCursor-notary"

# Get version from argument or git tag
VERSION="${1:-$(git -C "$PROJECT_DIR" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0")}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "error: version must look like 1.2.3 (got '$VERSION')" >&2; exit 1; }
# Build number must increase with every release; the commit count does.
BUILD_NUMBER="$(git -C "$PROJECT_DIR" rev-list --count HEAD)"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
ZIP_NAME="${APP_NAME}-${VERSION}.zip"

echo "=== Building EmojiCursor v${VERSION} (build ${BUILD_NUMBER}) ==="

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Step 1: Archive
echo ""
echo "=== Step 1: Archiving ==="
xcodebuild archive \
    -project "$PROJECT_DIR/EmojiCursor.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    -quiet

echo "Archive created at $ARCHIVE_PATH"

# Step 2: Export (signs with Developer ID + Hardened Runtime)
echo ""
echo "=== Step 2: Exporting ==="
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$PROJECT_DIR/ExportOptions.plist" \
    -quiet

APP_PATH="$EXPORT_DIR/${APP_NAME}.app"
echo "Exported to $APP_PATH"

# Step 3: Notarize the app
echo ""
echo "=== Step 3: Notarizing app ==="
# Create a ZIP for notarization submission
NOTARIZE_ZIP="$BUILD_DIR/${APP_NAME}-notarize.zip"
ditto -c -k --keepParent "$APP_PATH" "$NOTARIZE_ZIP"

xcrun notarytool submit "$NOTARIZE_ZIP" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

rm "$NOTARIZE_ZIP"

# Step 4: Staple the notarization ticket
echo ""
echo "=== Step 4: Stapling ==="
xcrun stapler staple "$APP_PATH"

# Step 5: Verify
echo ""
echo "=== Step 5: Verifying ==="
spctl --assess --type execute --verbose=2 "$APP_PATH"
echo "Verification passed!"

# Step 6: Create DMG
echo ""
echo "=== Step 6: Creating DMG ==="
DMG_PATH="$BUILD_DIR/$DMG_NAME"
# create-dmg packages the *contents* of a folder, so stage the app in one.
DMG_STAGING="$BUILD_DIR/dmg"
mkdir -p "$DMG_STAGING"
ditto "$APP_PATH" "$DMG_STAGING/$APP_NAME.app"

ICON_ARGS=()
if [ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]; then
    ICON_ARGS=(--volicon "$APP_PATH/Contents/Resources/AppIcon.icns")
fi

# create-dmg can exit non-zero on cosmetic issues (e.g. Finder layout), so
# check for the DMG itself rather than trusting the exit code.
create-dmg \
    --volname "$APP_NAME" \
    ${ICON_ARGS[@]+"${ICON_ARGS[@]}"} \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 150 190 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 450 190 \
    "$DMG_PATH" \
    "$DMG_STAGING" \
    || true
[ -f "$DMG_PATH" ] || { echo "error: create-dmg did not produce $DMG_PATH" >&2; exit 1; }
codesign --sign "Developer ID Application" --timestamp "$DMG_PATH"

# Step 7: Notarize DMG
echo ""
echo "=== Step 7: Notarizing DMG ==="
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

xcrun stapler staple "$DMG_PATH"

# Step 8: Create ZIP for Homebrew
echo ""
echo "=== Step 8: Creating ZIP ==="
ZIP_PATH="$BUILD_DIR/$ZIP_NAME"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

# Output summary
echo ""
echo "=== Build Complete ==="
echo "App:  $APP_PATH"
echo "DMG:  $DMG_PATH"
echo "ZIP:  $ZIP_PATH"
echo ""
echo "SHA256 checksums:"
echo "  DMG: $(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
echo "  ZIP: $(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
echo ""
echo "Next steps (or just push a v${VERSION} tag and let CI do all of this):"
echo "  1. git tag v${VERSION} && git push origin v${VERSION}"
echo "  2. Upload DMG and ZIP to the GitHub release"
echo "  3. ./scripts/update-cask.sh ${VERSION} $(shasum -a 256 "$ZIP_PATH" | awk '{print $1}') and commit"
