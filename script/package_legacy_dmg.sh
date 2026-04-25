#!/usr/bin/env bash
set -euo pipefail

TARGET_NAME="PomodoroBarLegacy"
APP_NAME="PomodoroBar Legacy"
DMG_BASENAME="PomodoroBarLegacy"
APP_VERSION="v1.0-beta"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/PomodoroBar.xcodeproj"
DERIVED_DATA="$ROOT_DIR/build/DerivedDataLegacy"
RELEASE_APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist"
DIST_APP="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$DMG_BASENAME.dmg"
VERSIONED_DMG_PATH="$DIST_DIR/${DMG_BASENAME}_${APP_VERSION}.dmg"
PACKAGE_ROOT="/tmp/$DMG_BASENAME-package"
SIGNED_APP="$PACKAGE_ROOT/$APP_NAME.app"
TMP_DMG="/tmp/$DMG_BASENAME.tmp.dmg"
TMP_FINAL_DMG="/tmp/$DMG_BASENAME.dmg"
VOLUME_NAME="$APP_NAME $APP_VERSION"
STAGING_DIR="$PACKAGE_ROOT/dmg"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

xcodebuild \
  -project "$PROJECT" \
  -scheme "$TARGET_NAME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

mkdir -p "$DIST_DIR"
rm -rf "$DIST_APP" "$SIGNED_APP" "$STAGING_DIR" "$DMG_PATH" "$VERSIONED_DMG_PATH" "$TMP_DMG" "$TMP_FINAL_DMG"
mkdir -p "$PACKAGE_ROOT" "$STAGING_DIR"
/usr/bin/ditto --norsrc --noextattr "$RELEASE_APP" "$SIGNED_APP"

/usr/bin/xattr -cr "$SIGNED_APP"
/usr/bin/codesign --force --deep --sign - "$SIGNED_APP"

/usr/bin/lipo -info "$SIGNED_APP/Contents/MacOS/$APP_NAME" | /usr/bin/grep -q "arm64"
/usr/bin/lipo -info "$SIGNED_APP/Contents/MacOS/$APP_NAME" | /usr/bin/grep -q "x86_64"

/usr/bin/ditto --norsrc --noextattr "$SIGNED_APP" "$DIST_APP"
/usr/bin/ditto --norsrc --noextattr "$SIGNED_APP" "$STAGING_DIR/$APP_NAME.app"
/usr/bin/xattr -cr "$STAGING_DIR/$APP_NAME.app"
/usr/bin/codesign --force --deep --sign - "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

/usr/bin/hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -fs APFS \
  -format UDRW \
  "$TMP_DMG"

/usr/bin/hdiutil convert "$TMP_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$TMP_FINAL_DMG"

/bin/cp "$TMP_FINAL_DMG" "$DMG_PATH"
/bin/cp "$TMP_FINAL_DMG" "$VERSIONED_DMG_PATH"
rm -rf "$STAGING_DIR" "$TMP_DMG" "$TMP_FINAL_DMG"

echo "Legacy app: $DIST_APP"
echo "Legacy DMG: $DMG_PATH"
echo "Legacy versioned DMG: $VERSIONED_DMG_PATH"
