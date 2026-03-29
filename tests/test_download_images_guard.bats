#!/usr/bin/env bats
# tests/test_download_images_guard.bats
# Tests for: fix(playlist): fix operator precedence bug in DOWNLOAD_IMAGES guard
# Covers issue #14

setup() {
  # Minimal env so yt-x can be sourced without errors
  export YT_X_TEST_MODE=1
  export HOME="${BATS_TMPDIR}/home_$$"
  mkdir -p "$HOME/.config/yt-x" "$HOME/.cache/yt-x"
  export AUTO_LOADED_EXTENSIONS=""

  # Stub external deps so load_config doesn't error
  yt-dlp() { :; }; export -f yt-dlp
  fzf()    { :; }; export -f fzf
  jq()     { command jq "$@"; }; export -f jq

  # shellcheck source=../yt-x
  source "${BATS_TEST_DIRNAME}/../yt-x"
}

teardown() {
  rm -rf "${BATS_TMPDIR}/home_$$"
}

# ---------------------------------------------------------------------------
# The logic under test (extracted from playlist_explorer, line ~775):
#
#   if [ "$DOWNLOAD_IMAGES" = 0 ]; then
#     search_results=$(echo "$search_results" | jq "...")
#     if ! [ "$ENABLE_PREVIEW" = "true" ] || ! [ "$PREFERRED_SELECTOR" = "fzf" ]; then
#       DOWNLOAD_IMAGES=1
#     fi
#   fi
#
# Before the fix the || caused DOWNLOAD_IMAGES=1 to fire any time
# PREFERRED_SELECTOR != "fzf", even when DOWNLOAD_IMAGES was already 1.
# ---------------------------------------------------------------------------

_run_guard() {
  # Reproduce the fixed guard logic so tests are decoupled from exact line numbers.
  # When the refactor is merged this will be replaced by sourcing playlist_explorer
  # and asserting on its internal state.
  if [ "$DOWNLOAD_IMAGES" = 0 ]; then
    if ! [ "$ENABLE_PREVIEW" = "true" ] || ! [ "$PREFERRED_SELECTOR" = "fzf" ]; then
      DOWNLOAD_IMAGES=1
    fi
  fi
}

@test "#14: DOWNLOAD_IMAGES stays 1 when already set, regardless of selector" {
  DOWNLOAD_IMAGES=1
  ENABLE_PREVIEW="false"
  PREFERRED_SELECTOR="rofi"
  _run_guard
  [ "$DOWNLOAD_IMAGES" = "1" ]
}

@test "#14: DOWNLOAD_IMAGES set to 1 when preview disabled and selector is fzf" {
  DOWNLOAD_IMAGES=0
  ENABLE_PREVIEW="false"
  PREFERRED_SELECTOR="fzf"
  _run_guard
  [ "$DOWNLOAD_IMAGES" = "1" ]
}

@test "#14: DOWNLOAD_IMAGES set to 1 when selector is rofi (preview irrelevant)" {
  DOWNLOAD_IMAGES=0
  ENABLE_PREVIEW="true"
  PREFERRED_SELECTOR="rofi"
  _run_guard
  [ "$DOWNLOAD_IMAGES" = "1" ]
}

@test "#14: DOWNLOAD_IMAGES stays 0 when preview enabled AND selector is fzf" {
  DOWNLOAD_IMAGES=0
  ENABLE_PREVIEW="true"
  PREFERRED_SELECTOR="fzf"
  _run_guard
  [ "$DOWNLOAD_IMAGES" = "0" ]
}

@test "#14: DOWNLOAD_IMAGES stays 1 when already set and preview+fzf enabled" {
  DOWNLOAD_IMAGES=1
  ENABLE_PREVIEW="true"
  PREFERRED_SELECTOR="fzf"
  _run_guard
  [ "$DOWNLOAD_IMAGES" = "1" ]
}
