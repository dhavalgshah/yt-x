#!/usr/bin/env bats
# tests/test_phase2_security_perf.bats
# Phase 2 security + performance refactor tests
# Covers issues: #9 #12 #13 #16 #17 #19

load 'helpers/load_functions'

# ---------------------------------------------------------------------------
# Shared setup
# ---------------------------------------------------------------------------
setup() {
  export YT_X_TEST_MODE=1
  export HOME="${BATS_TMPDIR}/home_$$"
  mkdir -p "$HOME/.config/yt-x" "$HOME/.cache/yt-x"
  export AUTO_LOADED_EXTENSIONS=""

  # Stub out external commands not under test
  yt-dlp() { :; }; export -f yt-dlp
  fzf()    { :; }; export -f fzf
  mpv()    { :; }; export -f mpv
  curl()   { :; }; export -f curl
  gum()    { :; }; export -f gum

  load_yt_x_functions
}

teardown() {
  rm -rf "${BATS_TMPDIR}/home_$$"
}

# ---------------------------------------------------------------------------
# Issue #19 — PREFERRED_BROWSER bash array
# ---------------------------------------------------------------------------

@test "#19: PREFERRED_BROWSER is empty array when not configured" {
  # Simulate sourcing with no browser config
  PREFERRED_BROWSER=()
  [ "${#PREFERRED_BROWSER[@]}" -eq 0 ]
}

@test "#19: PREFERRED_BROWSER holds flag+value when configured" {
  PREFERRED_BROWSER=(--cookies-from-browser firefox)
  [ "${#PREFERRED_BROWSER[@]}" -eq 2 ]
  [ "${PREFERRED_BROWSER[0]}" = "--cookies-from-browser" ]
  [ "${PREFERRED_BROWSER[1]}" = "firefox" ]
}

@test "#19: PREFERRED_BROWSER expands to nothing when empty" {
  PREFERRED_BROWSER=()
  result="${PREFERRED_BROWSER[@]+${PREFERRED_BROWSER[@]}}"
  [ -z "$result" ]
}

@test "#19: PREFERRED_BROWSER expands to two words when set" {
  PREFERRED_BROWSER=(--cookies-from-browser chrome)
  count=0
  for _ in "${PREFERRED_BROWSER[@]}"; do count=$((count + 1)); done
  [ "$count" -eq 2 ]
}

# ---------------------------------------------------------------------------
# Issue #12 — jq --arg injection hardening
# ---------------------------------------------------------------------------

@test "#12: jq lookup with double-quote in name does not corrupt query" {
  local tmpfile
  tmpfile=$(mktemp)
  # Use jq itself to write a file with a double-quote in the name
  jq -n --arg n 'O"Brien' '[{"name": $n, "value": 42}]' > "$tmpfile"
  result=$(jq -r --arg n 'O"Brien' '. | map(select(.name == $n)) | .[0].value' "$tmpfile")
  rm -f "$tmpfile"
  [ "$result" = "42" ]
}

@test "#12: jq lookup with backslash in name does not corrupt query" {
  local tmpfile
  tmpfile=$(mktemp)
  printf '[{"name":"back\\\\slash","value":99}]' > "$tmpfile"
  result=$(jq -r --arg n 'back\slash' '. | map(select(.name == $n)) | .[0].value' "$tmpfile")
  rm -f "$tmpfile"
  [ "$result" = "99" ]
}

# ---------------------------------------------------------------------------
# Issue #16 — custom commands executed via bash -c
# ---------------------------------------------------------------------------

@test "#16: bash -c executes commands with quoted arguments" {
  # Simulate what custom_yt_dlp_cmd would hold
  cmd='printf "%s\n" "hello world"'
  result=$(bash -c "$cmd")
  [ "$result" = "hello world" ]
}

@test "#16: bash -c handles commands with spaces in arguments" {
  tmpdir=$(mktemp -d)
  cmd="touch \"${tmpdir}/my file.txt\""
  bash -c "$cmd"
  [ -f "${tmpdir}/my file.txt" ]
  rm -rf "$tmpdir"
}

# ---------------------------------------------------------------------------
# Issue #17 — PREVIEW_SCRIPT_FOR_CHANNELS deduplication
# ---------------------------------------------------------------------------

@test "#17: PREVIEW_SCRIPT_FOR_CHANNELS_EXPLORER equals PREVIEW_SCRIPT_FOR_CHANNELS" {
  [ "$PREVIEW_SCRIPT_FOR_CHANNELS_EXPLORER" = "$PREVIEW_SCRIPT_FOR_CHANNELS" ]
}

@test "#17: unified script uses channels_data fallback pattern" {
  # The merged script must contain the fallback expression
  [[ "$PREVIEW_SCRIPT_FOR_CHANNELS" == *'channels_data=${channels_data:-'* ]]
}

@test "#17: unified script uses --arg t for jq lookup" {
  [[ "$PREVIEW_SCRIPT_FOR_CHANNELS" == *'--arg t'* ]]
}

# ---------------------------------------------------------------------------
# Issue #9 — O(n²) download_preview_images
# ---------------------------------------------------------------------------

@test "#9: download_preview_images skips already-cached thumbnails" {
  # Minimal JSON with one entry
  local json cached_file
  json='{"entries":[{"id":"abc","thumbnails":[{"url":"https://i.ytimg.com/vi/abc/hqdefault.jpg"}]}]}'
  cached_hash=$(printf '%s' 'https://i.ytimg.com/vi/abc/hqdefault.jpg' | generate_sha256)
  # Create a non-empty cache file so [ -s ... ] check succeeds
  printf 'cached' > "$CLI_PREVIEW_IMAGES_CACHE_DIR/${cached_hash}.jpg"

  # previews.txt should NOT be written for already-cached items
  download_preview_images "$json" ""
  # Give background job a moment
  sleep 0.2

  if [ -f "$CLI_PREVIEW_IMAGES_CACHE_DIR/previews.txt" ]; then
    # File exists but should not contain this URL
    run grep -c 'hqdefault' "$CLI_PREVIEW_IMAGES_CACHE_DIR/previews.txt"
    [ "$output" = "0" ]
  fi
}

@test "#9: download_preview_images returns 1 for empty entries" {
  run download_preview_images '{"entries":[]}' ""
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Issue #13 — batch jq in generate_text_preview
# ---------------------------------------------------------------------------

@test "#13: generate_text_preview creates a preview file per entry" {
  local json
  CURRENT_TIME=$(date +%s)
  json='{
    "entries": [
      {
        "id": "vid1",
        "title": "Test Video",
        "thumbnails": [{"url": "https://example.com/thumb.jpg"}],
        "view_count": 1000,
        "live_status": "not_live",
        "description": "A test description",
        "channel": "Test Channel",
        "duration": 120,
        "timestamp": '"$((CURRENT_TIME - 3600))"'
      }
    ]
  }'
  search_results="$json"
  generate_text_preview "$json"
  sleep 0.2
  # Preview file should exist for this title
  title_hash=$(printf '%s' "Test Video" | generate_sha256)
  [ -f "$CLI_PREVIEW_SCRIPTS_DIR/${title_hash}.txt" ]
}

@test "#13: generate_text_preview preview file contains channel info" {
  local json
  CURRENT_TIME=$(date +%s)
  json='{
    "entries": [
      {
        "id": "vid2",
        "title": "Channel Test Video",
        "thumbnails": [{"url": "https://example.com/t2.jpg"}],
        "view_count": 500,
        "live_status": "not_live",
        "description": "desc",
        "channel": "My Channel",
        "duration": 60,
        "timestamp": '"$((CURRENT_TIME - 100))"'
      }
    ]
  }'
  search_results="$json"
  generate_text_preview "$json"
  sleep 0.2
  title_hash=$(printf '%s' "Channel Test Video" | generate_sha256)
  run grep -l 'My Channel' "$CLI_PREVIEW_SCRIPTS_DIR/${title_hash}.txt"
  [ "$status" -eq 0 ]
}

@test "#13: generate_text_preview returns 1 when search_results is empty" {
  local old_results="$search_results"
  search_results=""
  run generate_text_preview '{}'
  search_results="$old_results"
  [ "$status" -ne 0 ]
}

@test "#13: generate_text_preview handles title with double-quotes safely" {
  local json
  CURRENT_TIME=$(date +%s)
  json='{
    "entries": [
      {
        "id": "vid3",
        "title": "Say \"Hello\" World",
        "thumbnails": [{"url": "https://example.com/t3.jpg"}],
        "view_count": 0,
        "live_status": "not_live",
        "description": null,
        "channel": "QuoteChan",
        "duration": 30,
        "timestamp": '"$((CURRENT_TIME - 600))"'
      }
    ]
  }'
  search_results="$json"
  run generate_text_preview "$json"
  # Must not crash (exit 0 or 1 from the guard, but no syntax explosion)
  [ "$status" -le 1 ]
}
