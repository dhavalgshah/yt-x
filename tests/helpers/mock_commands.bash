#!/usr/bin/env bash
# tests/helpers/mock_commands.bash
# Provides lightweight command stubs for testing yt-x functions in isolation.
# Source this file in bats setup() blocks.

# Stubs a command by creating a function that records calls and returns a
# configurable exit code. The stub writes "$cmd <args>" to $STUB_CALLS_FILE.
stub() {
  local cmd="$1"
  local exit_code="${2:-0}"
  local output="${3:-}"
  eval "
    ${cmd}() {
      echo \"${cmd} \$*\" >> \"\${STUB_CALLS_FILE}\"
      [ -n \"${output}\" ] && echo \"${output}\"
      return ${exit_code}
    }
    export -f ${cmd}
  "
}

# Assert that a stubbed command was called with expected arguments.
assert_stub_called_with() {
  local cmd="$1"; shift
  local expected="$cmd $*"
  grep -qF "$expected" "$STUB_CALLS_FILE" || {
    echo "Expected stub call: '$expected'"
    echo "Actual calls in $STUB_CALLS_FILE:"
    cat "$STUB_CALLS_FILE"
    return 1
  }
}

# Assert a stubbed command was never called.
assert_stub_not_called() {
  local cmd="$1"
  grep -q "^$cmd " "$STUB_CALLS_FILE" && {
    echo "Expected '$cmd' NOT to be called, but it was:"
    grep "^$cmd " "$STUB_CALLS_FILE"
    return 1
  }
  return 0
}
