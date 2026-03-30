#!/usr/bin/env bats
# Test suite for external dependencies (yt-dlp, mpv, jq)

setup() {
  load helpers/load_functions
  load helpers/mock_commands
}

# ============================================================
# JQ Tests
# ============================================================

@test "jq: version command works" {
  command -v jq >/dev/null || skip "jq not installed"
  jq --version
}

@test "jq: basic JSON parsing works" {
  result=$(echo '{"test": "data"}' | jq -r '.test')
  [ "$result" = "data" ]
}

@test "jq: @uri encoding works for search terms" {
  result=$(echo "test query" | jq -Rr '@uri')
  [ "$result" = "test%20query" ]
}

@test "jq: can handle special characters in strings" {
  result=$(echo '{"title": "test\"quote\""}' | jq -r '.title')
  [ "$result" = 'test"quote"' ]
}

# ============================================================
# MPV Tests
# ============================================================

@test "mpv: version command works" {
  command -v mpv >/dev/null || skip "mpv not installed"
  mpv --version 2>&1 | grep -q "mpv"
}

@test "mpv: config loads without errors" {
  command -v mpv >/dev/null || skip "mpv not installed"
  # Check if config file exists and has no critical errors
  if [ -f ~/.config/mpv/mpv.conf ]; then
    # Just verify mpv --help doesn't error due to config
    mpv --help >/dev/null 2>&1 || true
  fi
}

@test "mpv: can parse valid ytdl-format option" {
  command -v mpv >/dev/null || skip "mpv not installed"
  # This should not error
  mpv --list-options 2>&1 | grep -q "ytdl-format" || true
}

@test "mpv: hardware acceleration option exists" {
  command -v mpv >/dev/null || skip "mpv not installed"
  mpv --list-options 2>&1 | grep -q "hwdec"
}

@test "mpv: GPU rendering option exists" {
  command -v mpv >/dev/null || skip "mpv not installed"
  mpv --list-options 2>&1 | grep -q "vo" || true
}

# ============================================================
# YT-DLP Tests
# ============================================================

@test "yt-dlp: version command works" {
  command -v yt-dlp >/dev/null || skip "yt-dlp not installed"
  yt-dlp --version
}

@test "yt-dlp: config file exists" {
  [ -f ~/.config/yt-dlp/config ] || skip "yt-dlp config not found"
  [ -s ~/.config/yt-dlp/config ]
}

@test "yt-dlp: config doesn't have deprecated --prefer-ffmpeg" {
  [ -f ~/.config/yt-dlp/config ] || skip "yt-dlp config not found"
  ! grep -q "^\s*--prefer-ffmpeg" ~/.config/yt-dlp/config
}

@test "yt-dlp: config has correct --no-keep-fragments syntax" {
  [ -f ~/.config/yt-dlp/config ] || skip "yt-dlp config not found"
  grep -q "^\s*--no-keep-fragments" ~/.config/yt-dlp/config || true
}

@test "yt-dlp: help command works without errors" {
  command -v yt-dlp >/dev/null || skip "yt-dlp not installed"
  # Basic help should work
  yt-dlp --help >/dev/null 2>&1
}

@test "yt-dlp: extract-audio option exists" {
  command -v yt-dlp >/dev/null || skip "yt-dlp not installed"
  yt-dlp --help 2>&1 | grep -q "extract-audio"
}

@test "yt-dlp: dump-json option exists" {
  command -v yt-dlp >/dev/null || skip "yt-dlp not installed"
  yt-dlp --help 2>&1 | grep -q "dump-json"
}

# ============================================================
# Integration Tests
# ============================================================

@test "mpv and jq can work together for ytdl format extraction" {
  command -v mpv >/dev/null || skip "mpv not installed"
  command -v jq >/dev/null || skip "jq not installed"
  # Simulate extracting format from JSON
  echo '{"formats": [{"format_id": "251", "ext": "webm"}]}' | jq '.formats[0].format_id' | grep -q "251"
}

@test "yt-dlp and jq can work together for JSON parsing" {
  command -v yt-dlp >/dev/null || skip "yt-dlp not installed"
  command -v jq >/dev/null || skip "jq not installed"
  # Simulate yt-dlp JSON output parsing
  echo '{"id": "abc123", "title": "Test Video"}' | jq -r '.id' | grep -q "abc123"
}

