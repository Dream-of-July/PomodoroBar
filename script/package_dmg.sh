#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PomodoroBar"
APP_VERSION="1.0 RC"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
VERSIONED_DMG_PATH="$DIST_DIR/${APP_NAME}_${APP_VERSION}.dmg"
PACKAGE_ROOT="/tmp/$APP_NAME-package"
SIGNED_APP="$PACKAGE_ROOT/$APP_NAME.app"
TMP_DMG="/tmp/$APP_NAME.tmp.dmg"
TMP_FINAL_DMG="/tmp/$APP_NAME.dmg"
VOLUME_NAME="$APP_NAME $APP_VERSION"
STAGING_DIR="$PACKAGE_ROOT/dmg"

source "$ROOT_DIR/script/sparkle_appcast.sh"

"$ROOT_DIR/script/package_app.sh"

clear_extended_attributes() {
  local path="$1"
  /usr/bin/xattr -cr "$path"
  /usr/bin/find "$path" -exec /usr/bin/xattr -c {} \; >/dev/null 2>&1 || true
  /usr/bin/find -H "$path" -exec /usr/bin/xattr -c {} \; >/dev/null 2>&1 || true
  local sparkle_updater="$path/Contents/Frameworks/Sparkle.framework/Versions/Current/Updater.app"
  if [[ -e "$sparkle_updater" ]]; then
    /usr/bin/xattr -d com.apple.FinderInfo "$sparkle_updater" >/dev/null 2>&1 || true
    /usr/bin/xattr -d 'com.apple.fileprovider.fpfs#P' "$sparkle_updater" >/dev/null 2>&1 || true
  fi
}

rm -rf "$STAGING_DIR" "$DMG_PATH" "$VERSIONED_DMG_PATH" "$DIST_DIR/PomodoroBar Universal.app" "$DIST_DIR/PomodoroBarUniversal.dmg" "$DIST_DIR/PomodoroBarUniversal_${APP_VERSION}.dmg" "$TMP_DMG" "$TMP_FINAL_DMG"
mkdir -p "$STAGING_DIR"
find "$DIST_DIR" -maxdepth 1 -name "${APP_NAME}_v*.dmg" ! -name "${APP_NAME}_${APP_VERSION}.dmg" -delete

clear_extended_attributes "$SIGNED_APP"
/usr/bin/codesign --force --deep --sign - "$SIGNED_APP"
/usr/bin/ditto --norsrc --noextattr "$SIGNED_APP" "$STAGING_DIR/$APP_NAME.app"
clear_extended_attributes "$STAGING_DIR/$APP_NAME.app"
/usr/bin/codesign --force --deep --sign - "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

/usr/bin/hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -fs APFS \
  -format UDRW \
  "$TMP_DMG"

/usr/bin/hdiutil convert "$TMP_DMG" \
  -format ULFO \
  -o "$TMP_FINAL_DMG"

/bin/cp "$TMP_FINAL_DMG" "$DMG_PATH"
/bin/cp "$TMP_FINAL_DMG" "$VERSIONED_DMG_PATH"
generate_sparkle_appcast "$VERSIONED_DMG_PATH" "appcast.xml" "26.0.0"
rm -rf "$STAGING_DIR" "$TMP_DMG" "$TMP_FINAL_DMG"

echo "DMG: $DMG_PATH"
echo "Versioned DMG: $VERSIONED_DMG_PATH"
