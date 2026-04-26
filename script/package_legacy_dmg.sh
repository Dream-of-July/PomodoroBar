#!/usr/bin/env bash
set -euo pipefail

TARGET_NAME="PomodoroBarLegacy"
APP_NAME="PomodoroBar Legacy"
DMG_BASENAME="PomodoroBarLegacy"
APP_VERSION="1.0 RC 2b"
APP_VERSION_ASSET="${APP_VERSION// /.}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/PomodoroBar.xcodeproj"
DERIVED_DATA="$ROOT_DIR/build/DerivedDataLegacy"
RELEASE_APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist"
DIST_APP="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$DMG_BASENAME.dmg"
VERSIONED_DMG_PATH="$DIST_DIR/${DMG_BASENAME}_${APP_VERSION_ASSET}.dmg"
PACKAGE_ROOT="/tmp/$DMG_BASENAME-package"
SIGNED_APP="$PACKAGE_ROOT/$APP_NAME.app"
TMP_DMG="/tmp/$DMG_BASENAME.tmp.dmg"
TMP_FINAL_DMG="/tmp/$DMG_BASENAME.dmg"
VOLUME_NAME="$APP_NAME $APP_VERSION"
STAGING_DIR="$PACKAGE_ROOT/dmg"

source "$ROOT_DIR/script/sparkle_appcast.sh"

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

verify_private_signature() {
  local path="$1"
  local details
  details="$(/usr/bin/codesign -dvvv "$path" 2>&1)"

  if ! /usr/bin/grep -q "Signature=adhoc" <<<"$details"; then
    echo "Privacy check failed: $path is not ad hoc signed." >&2
    echo "$details" >&2
    exit 1
  fi

  if /usr/bin/grep -q "^Authority=" <<<"$details"; then
    echo "Privacy check failed: $path contains certificate authority metadata." >&2
    echo "$details" >&2
    exit 1
  fi

  if /usr/bin/grep -q "^TeamIdentifier=" <<<"$details" && ! /usr/bin/grep -q "^TeamIdentifier=not set" <<<"$details"; then
    echo "Privacy check failed: $path contains a team identifier." >&2
    echo "$details" >&2
    exit 1
  fi
}

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

xcodebuild \
  -project "$PROJECT" \
  -scheme "$TARGET_NAME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://github.com/Dream-of-July/PomodoroBar/releases/latest/download/appcast-legacy.xml}" \
  SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-K3bwNLuBP5M9s+VX6DyZQVntWxGg6vMVlaxq2Bxkgow=}" \
  CODE_SIGNING_ALLOWED=NO \
  build

mkdir -p "$DIST_DIR"
rm -rf "$DIST_APP" "$SIGNED_APP" "$STAGING_DIR" "$DMG_PATH" "$VERSIONED_DMG_PATH" "$TMP_DMG" "$TMP_FINAL_DMG"
mkdir -p "$PACKAGE_ROOT" "$STAGING_DIR"
/usr/bin/ditto --norsrc --noextattr "$RELEASE_APP" "$SIGNED_APP"

clear_extended_attributes "$SIGNED_APP"
/usr/bin/codesign --force --deep --sign - "$SIGNED_APP"
verify_private_signature "$SIGNED_APP"

/usr/bin/lipo -info "$SIGNED_APP/Contents/MacOS/$APP_NAME" | /usr/bin/grep -q "arm64"
/usr/bin/lipo -info "$SIGNED_APP/Contents/MacOS/$APP_NAME" | /usr/bin/grep -q "x86_64"

/usr/bin/ditto --norsrc --noextattr "$SIGNED_APP" "$DIST_APP"
/usr/bin/ditto --norsrc --noextattr "$SIGNED_APP" "$STAGING_DIR/$APP_NAME.app"
clear_extended_attributes "$STAGING_DIR/$APP_NAME.app"
/usr/bin/codesign --force --deep --sign - "$STAGING_DIR/$APP_NAME.app"
verify_private_signature "$STAGING_DIR/$APP_NAME.app"
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
generate_sparkle_appcast "$VERSIONED_DMG_PATH" "appcast-legacy.xml" "13.0.0"
rm -rf "$STAGING_DIR" "$TMP_DMG" "$TMP_FINAL_DMG"

echo "Legacy app: $DIST_APP"
echo "Legacy DMG: $DMG_PATH"
echo "Legacy versioned DMG: $VERSIONED_DMG_PATH"
