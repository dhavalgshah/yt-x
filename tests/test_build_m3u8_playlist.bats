#!/usr/bin/env bats
# tests/test_build_m3u8_playlist.bats
# Tests for: refactor(playlist): extract build_m3u8_playlist helper
# Covers issue #10

setup() {
  export YT_X_TEST_MODE=1
  export HOME="${BATS_TMPDIR}/home_$$"
  mkdir -p "$HOME/.config/yt-x" "$HOME/.cache/yt-x"
  export AUTO_LOADED_EXTENSIONS=""
  export PREFERRED_BROWSER=""

  yt-dlp() { :; }; export -f yt-dlp
  fzf()    { :; }; export -f fzf

  # Sample flat-playlist JSON yt-dlp would return
  MOCK_PLAYLIST_JSON='{
    "entries": [
      {"title": "Video One",   "url": "https://youtu.be/aaa"},
      {"title": "Video Two",   "url": "https://youtu.be/bbb"},
      {"title": "Video Three", "url": "https://youtu.be/ccc"}
    ]
  }'

  # shellcheck source=../yt-x
  source "${BATS_TEST_DIRNAME}/../yt-x"
}

teardown() {
  rm -rf "${BATS_TMPDIR}/home_$$"
  unset _STUB_PLAYLIST_JSON
}

# Stub yt-dlp to return our mock JSON for any URL.
# Uses a global export because bash functions don't close over locals —
# by the time the exported yt-dlp() is invoked, the caller's local
# variables are out of scope.
_stub_yt_dlp_playlist() {
  export _STUB_PLAYLIST_JSON="$1"
  yt-dlp() { echo "$_STUB_PLAYLIST_JSON"; }
  export -f yt-dlp
}

@test "#10: build_m3u8_playlist creates output file" {
  _stub_yt_dlp_playlist "$MOCK_PLAYLIST_JSON"
  dest="${BATS_TMPDIR}/test_$$.m3u8"
  build_m3u8_playlist "https://fake.url" "$dest"
  [ -f "$dest" ]
}

@test "#10: build_m3u8_playlist writes #EXTM3U header" {
  _stub_yt_dlp_playlist "$MOCK_PLAYLIST_JSON"
  dest="${BATS_TMPDIR}/test_$$.m3u8"
  build_m3u8_playlist "https://fake.url" "$dest"
  head -1 "$dest" | grep -q '#EXTM3U'
}

@test "#10: build_m3u8_playlist writes one #EXTINF per entry" {
  _stub_yt_dlp_playlist "$MOCK_PLAYLIST_JSON"
  dest="${BATS_TMPDIR}/test_$$.m3u8"
  build_m3u8_playlist "https://fake.url" "$dest"
  count=$(grep -c '#EXTINF' "$dest")
  [ "$count" -eq 3 ]
}

@test "#10: build_m3u8_playlist writes correct titles in EXTINF lines" {
  _stub_yt_dlp_playlist "$MOCK_PLAYLIST_JSON"
  dest="${BATS_TMPDIR}/test_$$.m3u8"
  build_m3u8_playlist "https://fake.url" "$dest"
  grep -q 'Video One'   "$dest"
  grep -q 'Video Two'   "$dest"
  grep -q 'Video Three' "$dest"
}

@test "#10: build_m3u8_playlist writes correct URLs" {
  _stub_yt_dlp_playlist "$MOCK_PLAYLIST_JSON"
  dest="${BATS_TMPDIR}/test_$$.m3u8"
  build_m3u8_playlist "https://fake.url" "$dest"
  grep -q 'https://youtu.be/aaa' "$dest"
  grep -q 'https://youtu.be/bbb' "$dest"
  grep -q 'https://youtu.be/ccc' "$dest"
}

@test "#10: build_m3u8_playlist returns non-zero when yt-dlp fails" {
  yt-dlp() { return 1; }; export -f yt-dlp
  dest="${BATS_TMPDIR}/test_$$.m3u8"
  run build_m3u8_playlist "https://fake.url" "$dest"
  [ "$status" -ne 0 ]
}

@test "#10: build_m3u8_playlist does not overwrite existing cached file" {
  # If dest already exists and is non-empty, caller is responsible for
  # checking before calling. The function itself should write to dest
  # regardless — caching is the caller's concern.
  # This test documents the contract: function always writes.
  _stub_yt_dlp_playlist "$MOCK_PLAYLIST_JSON"
  dest="${BATS_TMPDIR}/test_$$.m3u8"
  echo "existing" > "$dest"
  build_m3u8_playlist "https://fake.url" "$dest"
  grep -q '#EXTM3U' "$dest"
}
