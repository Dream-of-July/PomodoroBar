#!/usr/bin/env bash

find_sparkle_tool() {
  local tool_name="$1"

  if [[ -n "${SPARKLE_BIN:-}" && -x "$SPARKLE_BIN/$tool_name" ]]; then
    printf '%s\n' "$SPARKLE_BIN/$tool_name"
    return 0
  fi

  if command -v "$tool_name" >/dev/null 2>&1; then
    command -v "$tool_name"
    return 0
  fi

  find "$ROOT_DIR/build" "$HOME/Library/Developer/Xcode/DerivedData" \
    -path "*/SourcePackages/artifacts/sparkle/Sparkle/bin/$tool_name" \
    -type f \
    -perm -111 \
    2>/dev/null | head -n 1
}

generate_sparkle_appcast() {
  local archive_path="$1"
  local appcast_name="$2"
  local minimum_system_version="$3"

  local generator
  generator="$(find_sparkle_tool generate_appcast || true)"

  if [[ -z "$generator" ]]; then
    echo "Skipping Sparkle appcast: generate_appcast was not found." >&2
    echo "Resolve Swift packages or set SPARKLE_BIN to Sparkle/bin before packaging." >&2
    [[ "${SPARKLE_REQUIRE_APPCAST:-0}" == "1" ]] && return 1
    return 0
  fi

  local release_tag="${RELEASE_TAG:-v1.0-rc2}"
  local release_url="${RELEASE_URL:-https://github.com/Dream-of-July/PomodoroBar/releases/download/$release_tag}"
  local update_dir="$DIST_DIR/sparkle/${appcast_name%.xml}"
  local output_appcast="$update_dir/$appcast_name"
  local public_appcast="$DIST_DIR/$appcast_name"
  local archive_name
  archive_name="$(basename "$archive_path")"

  rm -rf "$update_dir"
  mkdir -p "$update_dir"
  /bin/cp "$archive_path" "$update_dir/$archive_name"
  /bin/cp "$ROOT_DIR/release-notes/1.0-rc2.en.html" "$DIST_DIR/1.0-rc2.en.html"
  /bin/cp "$ROOT_DIR/release-notes/1.0-rc2.zh-Hans.html" "$DIST_DIR/1.0-rc2.zh-Hans.html"

  local args=(
    --account "${SPARKLE_KEY_ACCOUNT:-PomodoroBar}"
    --download-url-prefix "$release_url/"
    --link "https://github.com/Dream-of-July/PomodoroBar"
    --maximum-deltas 16
    --delta-compression lzfse
    -o "$output_appcast"
  )

  if [[ -n "${SPARKLE_EDDSA_KEY_FILE:-}" ]]; then
    args+=(--ed-key-file "$SPARKLE_EDDSA_KEY_FILE")
  fi

  "$generator" "${args[@]}" "$update_dir"
  ensure_minimum_system_version "$output_appcast" "$minimum_system_version"
  "$generator" "${args[@]}" "$update_dir"
  add_localized_release_notes "$output_appcast" "$release_url"
  ensure_minimum_system_version "$output_appcast" "$minimum_system_version"

  /bin/cp "$output_appcast" "$public_appcast"
  find "$update_dir" -maxdepth 1 -name '*.delta' -exec /bin/cp {} "$DIST_DIR" \;
  echo "Sparkle appcast: $public_appcast"
}

add_localized_release_notes() {
  local appcast="$1"
  local release_url="$2"
  local en_url="$release_url/1.0-rc2.en.html"
  local zh_url="$release_url/1.0-rc2.zh-Hans.html"
  local notes_xml

  notes_xml="$(printf '<sparkle:releaseNotesLink xml:lang="en">%s</sparkle:releaseNotesLink>\n        <sparkle:releaseNotesLink xml:lang="zh-Hans">%s</sparkle:releaseNotesLink>' "$en_url" "$zh_url")"

  if /usr/bin/grep -q '<sparkle:releaseNotesLink' "$appcast"; then
    /usr/bin/perl -0pi -e "s#\\s*<sparkle:releaseNotesLink[^>]*>.*?</sparkle:releaseNotesLink>#\n        $notes_xml#s" "$appcast"
  else
    /usr/bin/perl -0pi -e "s#(\\s*</item>)#\n        $notes_xml\$1#s" "$appcast"
  fi
}

ensure_minimum_system_version() {
  local appcast="$1"
  local minimum_system_version="$2"

  if /usr/bin/grep -q '<sparkle:minimumSystemVersion>' "$appcast"; then
    /usr/bin/perl -0pi -e "s#<sparkle:minimumSystemVersion>.*?</sparkle:minimumSystemVersion>#<sparkle:minimumSystemVersion>$minimum_system_version</sparkle:minimumSystemVersion>#s" "$appcast"
  else
    /usr/bin/perl -0pi -e "s#(\\s*</item>)#\n        <sparkle:minimumSystemVersion>$minimum_system_version</sparkle:minimumSystemVersion>\$1#s" "$appcast"
  fi
}
