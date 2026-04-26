#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PomodoroBar"
APP_VERSION="1.0 RC 2b"
INSTALL_TO_APPLICATIONS="${INSTALL_TO_APPLICATIONS:-1}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/PomodoroBar.xcodeproj"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
RELEASE_APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist"
DIST_APP="$DIST_DIR/$APP_NAME.app"
PACKAGE_ROOT="/tmp/$APP_NAME-package"
SIGNED_APP="$PACKAGE_ROOT/$APP_NAME.app"
APPLICATIONS_APP="/Applications/$APP_NAME.app"

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
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://github.com/Dream-of-July/PomodoroBar/releases/latest/download/appcast.xml}" \
  SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-K3bwNLuBP5M9s+VX6DyZQVntWxGg6vMVlaxq2Bxkgow=}" \
  CODE_SIGNING_ALLOWED=NO \
  build

mkdir -p "$DIST_DIR"
find "$DIST_DIR" -maxdepth 1 -name "${APP_NAME}_v*.app" -exec rm -rf {} +
rm -rf "$DIST_APP" "$SIGNED_APP"
mkdir -p "$PACKAGE_ROOT"
/usr/bin/ditto --norsrc --noextattr "$RELEASE_APP" "$SIGNED_APP"

clear_extended_attributes "$SIGNED_APP"
/usr/bin/codesign --force --deep --sign - "$SIGNED_APP"
verify_private_signature "$SIGNED_APP"

/usr/bin/lipo -info "$SIGNED_APP/Contents/MacOS/$APP_NAME" | /usr/bin/grep -q "arm64"
/usr/bin/lipo -info "$SIGNED_APP/Contents/MacOS/$APP_NAME" | /usr/bin/grep -q "x86_64"

/usr/bin/ditto --norsrc --noextattr "$SIGNED_APP" "$DIST_APP"

if [[ "$INSTALL_TO_APPLICATIONS" == "1" ]]; then
  rm -rf "$APPLICATIONS_APP"
  /usr/bin/ditto --norsrc --noextattr "$SIGNED_APP" "$APPLICATIONS_APP"
  clear_extended_attributes "$APPLICATIONS_APP"
  /usr/bin/codesign --force --deep --sign - "$APPLICATIONS_APP"
  verify_private_signature "$APPLICATIONS_APP"
  /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted "$APPLICATIONS_APP"
  echo "Installed: $APPLICATIONS_APP"
else
  echo "Install skipped: $APPLICATIONS_APP"
fi

echo "Packaged: $DIST_APP"
