#!/usr/bin/env bats
# tests/test_notify_info.bats
# Tests for: fix(ui): add notify_info for non-blocking status messages
# Covers issue #18

setup() {
  export YT_X_TEST_MODE=1
  export HOME="${BATS_TMPDIR}/home_$$"
  mkdir -p "$HOME/.config/yt-x" "$HOME/.cache/yt-x"
  export AUTO_LOADED_EXTENSIONS=""
  export NOTIFICATION_DURATION=5   # would cause a 5s sleep if misused

  yt-dlp() { :; }; export -f yt-dlp
  fzf()    { :; }; export -f fzf

  # shellcheck source=../yt-x
  source "${BATS_TEST_DIRNAME}/../yt-x"
}

teardown() {
  rm -rf "${BATS_TMPDIR}/home_$$"
}

# ---------------------------------------------------------------------------
# notify_info — writes to stderr, does NOT sleep
# send_notification — writes to stderr AND sleeps NOTIFICATION_DURATION secs
# ---------------------------------------------------------------------------

@test "#18: notify_info prints message to stderr" {
  run bash -c "
    YT_X_TEST_MODE=1 HOME='${BATS_TMPDIR}/home_$$' AUTO_LOADED_EXTENSIONS=''
    source '${BATS_TEST_DIRNAME}/../yt-x'
    notify_info 'hello world' 2>&1
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"hello world"* ]]
}

@test "#18: notify_info completes in under 500ms (no sleep)" {
  start_ms=$(date +%s%N)
  notify_info "quick message" 2>/dev/null
  end_ms=$(date +%s%N)
  elapsed=$(( (end_ms - start_ms) / 1000000 ))
  [ "$elapsed" -lt 500 ]
}

@test "#18: send_notification still sleeps (backward compat)" {
  # Override sleep so we can detect it was called without actually waiting
  sleep_called=0
  sleep() { sleep_called=1; }
  export -f sleep

  send_notification "error message" 2>/dev/null || true
  [ "$sleep_called" -eq 1 ]
}

@test "#18: notify_info does not call sleep" {
  sleep_called=0
  sleep() { sleep_called=1; }
  export -f sleep

  notify_info "status message" 2>/dev/null
  [ "$sleep_called" -eq 0 ]
}

@test "#18: notify_info outputs to stderr not stdout" {
  stdout=$(notify_info "msg" 2>/dev/null)
  stderr=$(notify_info "msg" 2>&1 >/dev/null)
  [ -z "$stdout" ]
  [[ "$stderr" == *"msg"* ]]
}
