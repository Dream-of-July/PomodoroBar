#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PomodoroBar"
APP_VERSION="v1.0-beta"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/PomodoroBar.xcodeproj"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
RELEASE_APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist"
DIST_APP="$DIST_DIR/$APP_NAME.app"
PACKAGE_ROOT="/tmp/$APP_NAME-package"
SIGNED_APP="$PACKAGE_ROOT/$APP_NAME.app"
APPLICATIONS_APP="/Applications/$APP_NAME.app"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

xcodebuild \
  -project "$PROJECT" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

mkdir -p "$DIST_DIR"
find "$DIST_DIR" -maxdepth 1 -name "${APP_NAME}_v*.app" -exec rm -rf {} +
rm -rf "$DIST_APP" "$SIGNED_APP"
mkdir -p "$PACKAGE_ROOT"
/usr/bin/ditto --norsrc --noextattr "$RELEASE_APP" "$SIGNED_APP"

/usr/bin/xattr -cr "$SIGNED_APP"
/usr/bin/codesign --force --deep --sign - "$SIGNED_APP"
/usr/bin/ditto --norsrc --noextattr "$SIGNED_APP" "$DIST_APP"

rm -rf "$APPLICATIONS_APP"
/usr/bin/ditto --norsrc --noextattr "$SIGNED_APP" "$APPLICATIONS_APP"
/usr/bin/xattr -cr "$APPLICATIONS_APP"
/usr/bin/codesign --force --deep --sign - "$APPLICATIONS_APP"
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted "$APPLICATIONS_APP"

echo "Packaged: $DIST_APP"
echo "Installed: $APPLICATIONS_APP"
