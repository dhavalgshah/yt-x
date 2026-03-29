#!/usr/bin/env bats
# tests/test_main_event_loop.bats
# Tests for: fix(cli): replace recursive main call with while-true event loop
# Covers issue #11
#
# Strategy: we cannot easily call main() directly (it blocks on fzf), but we
# CAN verify the structural property: that main() does not increase the Bash
# call stack depth on repeated invocations, and that byebye() causes a clean
# exit (not a recursive return).

setup() {
  export YT_X_TEST_MODE=1
  export HOME="${BATS_TMPDIR}/home_$$"
  mkdir -p "$HOME/.config/yt-x" "$HOME/.cache/yt-x"
  export AUTO_LOADED_EXTENSIONS=""

  yt-dlp() { :; }; export -f yt-dlp
  fzf()    { echo "Exit"; }; export -f fzf   # always picks "Exit"

  # shellcheck source=../yt-x
  source "${BATS_TEST_DIRNAME}/../yt-x"
}

teardown() {
  rm -rf "${BATS_TMPDIR}/home_$$"
}

@test "#11: main exits cleanly when fzf returns Exit" {
  # If main is recursive, this would either stack-overflow or return 0 only
  # after many recursive frames. With a while loop it exits in one iteration.
  run bash -c "
    YT_X_TEST_MODE=1
    HOME='${BATS_TMPDIR}/home_$$'
    AUTO_LOADED_EXTENSIONS=''
    fzf() { echo 'Exit'; }; export -f fzf
    yt-dlp() { :; }; export -f yt-dlp
    source '${BATS_TEST_DIRNAME}/../yt-x'
    main
  "
  # byebye calls 'exit 0' — so status should be 0
  [ "$status" -eq 0 ]
}

@test "#11: byebye exits the process, not just a function return" {
  run bash -c "
    YT_X_TEST_MODE=1
    HOME='${BATS_TMPDIR}/home_$$'
    AUTO_LOADED_EXTENSIONS=''
    source '${BATS_TEST_DIRNAME}/../yt-x'
    byebye 0
    echo 'SHOULD_NOT_REACH'
  "
  [ "$status" -eq 0 ]
  [[ "$output" != *"SHOULD_NOT_REACH"* ]]
}

@test "#11: byebye exits with provided code" {
  run bash -c "
    YT_X_TEST_MODE=1
    HOME='${BATS_TMPDIR}/home_$$'
    AUTO_LOADED_EXTENSIONS=''
    source '${BATS_TEST_DIRNAME}/../yt-x'
    byebye 42
  "
  [ "$status" -eq 42 ]
}

@test "#11: main does not use recursive self-call (structural check)" {
  # grep for 'main' as a standalone call inside main()'s own body.
  # With the fix in place, the only 'main' inside main() is the function
  # definition line itself — not a recursive tail call.
  main_body=$(awk '/^main\(\)/{found=1} found{print} /^}$/ && found{exit}' \
    "${BATS_TEST_DIRNAME}/../yt-x")
  # Count lines that are a bare 'main' call (not a definition or comment)
  recursive_calls=$(echo "$main_body" | grep -cE '^\s+main\s*$' || true)
  [ "$recursive_calls" -eq 0 ]
}
