#!/usr/bin/env bats
# tests/test_open_in_editor.bats
# Tests for: refactor(ui): extract open_in_editor helper
# Covers issue #15

setup() {
  bats_require_minimum_version 1.5.0
  export YT_X_TEST_MODE=1
  export HOME="${BATS_TMPDIR}/home_$$"
  mkdir -p "$HOME/.config/yt-x" "$HOME/.cache/yt-x"
  export AUTO_LOADED_EXTENSIONS=""
  export STUB_CALLS_FILE="${BATS_TMPDIR}/stubs_$$.log"
  : > "$STUB_CALLS_FILE"

  yt-dlp() { :; }; export -f yt-dlp
  fzf()    { :; }; export -f fzf

  # shellcheck source=../yt-x
  source "${BATS_TEST_DIRNAME}/../yt-x"
}

teardown() {
  rm -rf "${BATS_TMPDIR}/home_$$" "$STUB_CALLS_FILE"
  unset PREFERRED_EDITOR EDITOR
}

# Helper: stub an editor command that records calls
_stub_editor() {
  local name="$1"
  eval "${name}() { echo \"${name} \$*\" >> \"\$STUB_CALLS_FILE\"; }"
  export -f "$name"
}

@test "#15: open_in_editor uses PREFERRED_EDITOR when set and available" {
  _stub_editor "myeditor"
  PREFERRED_EDITOR="myeditor"
  open_in_editor "/tmp/test.conf"
  grep -q "myeditor /tmp/test.conf" "$STUB_CALLS_FILE"
}

@test "#15: open_in_editor falls back to EDITOR when PREFERRED_EDITOR unset" {
  unset PREFERRED_EDITOR
  _stub_editor "fallback_editor"
  EDITOR="fallback_editor"
  open_in_editor "/tmp/test.conf"
  grep -q "fallback_editor /tmp/test.conf" "$STUB_CALLS_FILE"
}

@test "#15: open_in_editor falls back to xdg-open when no editor vars set" {
  unset PREFERRED_EDITOR EDITOR
  _stub_editor "xdg-open"
  open_in_editor "/tmp/test.conf"
  grep -q "xdg-open /tmp/test.conf" "$STUB_CALLS_FILE"
}

@test "#15: open_in_editor falls back to open (macOS) when xdg-open absent" {
  unset PREFERRED_EDITOR EDITOR
  # command -v finds bash functions, so we must both unset any xdg-open function
  # AND shadow the real binary by prepending an empty dir to PATH.
  unset -f xdg-open 2>/dev/null || true
  local _shadow _saved_path
  _shadow="${BATS_TMPDIR}/shadow_$$"
  _saved_path="$PATH"
  mkdir -p "$_shadow"
  _stub_editor "open"
  PATH="$_shadow" open_in_editor "/tmp/test.conf"
  grep -q "open /tmp/test.conf" "$STUB_CALLS_FILE"
}

@test "#15: open_in_editor returns non-zero and notifies when no editor found" {
  unset PREFERRED_EDITOR EDITOR
  xdg-open() { return 127; }; export -f xdg-open
  open()     { return 127; }; export -f open
  run -127 open_in_editor "/tmp/test.conf"
  [ "$status" -ne 0 ]
}

@test "#15: open_in_editor PREFERRED_EDITOR takes priority over EDITOR" {
  _stub_editor "pref_editor"
  _stub_editor "env_editor"
  PREFERRED_EDITOR="pref_editor"
  EDITOR="env_editor"
  open_in_editor "/tmp/test.conf"
  grep -q "pref_editor /tmp/test.conf" "$STUB_CALLS_FILE"
  ! grep -q "env_editor" "$STUB_CALLS_FILE"
}

@test "#15: open_in_editor passes file path with spaces correctly" {
  _stub_editor "myeditor"
  PREFERRED_EDITOR="myeditor"
  open_in_editor "/tmp/path with spaces/conf"
  grep -q "myeditor /tmp/path with spaces/conf" "$STUB_CALLS_FILE"
}
