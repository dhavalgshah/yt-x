#!/usr/bin/env bash
# tests/helpers/load_functions.bash
# Sources yt-x in a controlled way so individual functions can be tested
# without triggering the full startup sequence (config loading, dir creation,
# main loop, etc.).
#
# Usage in a bats test file:
#   load 'helpers/load_functions'
#
# After loading, all yt-x functions are available in the test process.
# External commands (yt-dlp, fzf, mpv, curl, etc.) must be stubbed by
# the calling test via stub() from mock_commands.bash.

load_yt_x_functions() {
  # Guard that prevents yt-x from executing its startup code when sourced.
  export YT_X_TEST_MODE=1

  # Minimal environment so load_config doesn't fail.
  export HOME="${BATS_TMPDIR}/home"
  mkdir -p "$HOME/.config/yt-x" "$HOME/.cache/yt-x"

  # Prevent load_config from writing files or launching auto-loaded extensions.
  export AUTO_LOADED_EXTENSIONS=""

  # Source the script — the startup guard (see yt-x bottom) will skip main.
  # shellcheck source=../yt-x
  source "${BATS_TEST_DIRNAME}/../yt-x"
}
