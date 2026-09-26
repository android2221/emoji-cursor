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
VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0")}"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
ZIP_NAME="${APP_NAME}-${VERSION}.zip"

echo "=== Building EmojiCursor v${VERSION} ==="

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
    | tail -5

echo "Archive created at $ARCHIVE_PATH"

# Step 2: Export (signs with Developer ID + Hardened Runtime)
echo ""
echo "=== Step 2: Exporting ==="
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$PROJECT_DIR/ExportOptions.plist" \
    | tail -5

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

create-dmg \
    --volname "$APP_NAME" \
    --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 150 190 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 450 190 \
    "$DMG_PATH" \
    "$APP_PATH" \
    || true  # create-dmg returns non-zero if no icon file found, but DMG is still created

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
echo "Next steps:"
echo "  1. git tag v${VERSION} && git push origin v${VERSION}"
echo "  2. Upload DMG and ZIP to GitHub Release"
echo "  3. Update Homebrew cask with new version and SHA256"
