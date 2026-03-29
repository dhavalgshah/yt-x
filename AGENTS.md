# AGENTS.md

Guidelines for AI agents (Copilot, Codex, etc.) working on this repository.

## Project Overview

**yt-x** is a single-file Bash CLI tool (`yt-x`) that lets users browse YouTube (and other yt-dlp-supported sites) from the terminal via an interactive TUI built on `fzf` or `rofi`.

- **Language:** Bash (single script, ~2050 lines)
- **Entry point:** `./yt-x`
- **Config:** `~/.config/yt-x/` (runtime, not in repo)
- **Extensions:** user scripts in `~/.config/yt-x/extensions/`; repo example at `extensions/example`

## Key Architecture

The entire application lives in `yt-x`. Major sections:

| Lines (approx) | Content |
|----------------|---------|
| 1–112 | Header, constants, config defaults |
| 113–210 | Config loading (`load_config`, `find_config_option`) |
| 211–560 | Utilities: notifications, fzf/rofi launcher, preview, image download |
| 560–624 | UI helpers: `welcome`, `byebye`, `prompt`, `run_yt_dlp` |
| 625–764 | Dependency checks (`core_dep_ch`) |
| 765–1391 | Core explorers: `playlist_explorer`, `playlists_explorer`, `channels_explorer`, `get_channels_data` |
| 1392–1779 | `main()` — top-level menu and routing |
| 1780–end | `usage()`, CLI argument parsing, entrypoint |

## Development Conventions

- **No build step.** The script is run directly; changes to `yt-x` are immediately effective.
- **ShellCheck compliance.** New code should pass `shellcheck yt-x`. Do not introduce warnings.
- **POSIX-ish Bash.** Use `bash` features freely, but avoid bashisms that break on Bash < 4. Target Bash 4+.
- **No external state in repo.** Config, cache, and playlists are all user-side (`~/.config/yt-x/`, `~/.cache/yt-x/`). Do not add files that persist state into the repo.
- **Extensions are user-space.** The `extensions/` directory in the repo contains only examples. Extensions override `main()` and can reuse all sourced helpers from the main script.
- **Version bumping.** The version is in `CLI_VERSION` near the top of `yt-x`. Bump it according to semver when making user-visible changes.
- **Changelog.** This project uses [git-cliff](https://github.com/orhun/git-cliff) with `cliff.toml`. Use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `refactor:`, etc.) for all commits.

## Testing

Automated tests live in `tests/` using [bats](https://github.com/bats-core/bats-core).

**Run all tests:**
```bash
bats tests/
```

**Test infrastructure:**
- `YT_X_TEST_MODE=1` guard at the bottom of `yt-x` prevents startup when sourced
- `tests/helpers/load_functions.bash` — sources `yt-x` and exposes all functions
- `tests/helpers/mock_commands.bash` — stub helpers for external tools
- Array variables (`PREFERRED_BROWSER`, etc.) cannot be exported — use `PREFERRED_BROWSER=()` directly in test `setup()`, not `export PREFERRED_BROWSER=""`

**Before committing:** `shellcheck yt-x` must pass with zero warnings.

**Manual testing** is still required for interactive paths (fzf/rofi selectors, mpv playback, yt-dlp downloads).

## Making Changes

1. **Edit only `yt-x`** for feature/bug changes. Supporting files: `README.md`, `flake.nix`, `default.nix`, `cliff.toml`.
2. Keep functions small and focused. Follow existing naming style (`snake_case`).
3. When touching the `launcher` / `fzf_preview` / `generate_text_preview` pipeline, verify both `fzf` and `rofi` selectors still work.
4. When touching `run_yt_dlp`, ensure the JSON output contract (`--dump-json`, `--flat-playlist`) is preserved — `playlist_explorer` depends on it heavily.
5. Print user-facing strings through `echo` / `printf`; never leak raw yt-dlp JSON to the user.
6. Respect the `PRETTY_PRINT` flag when adding any colored output (`$RED`, `$GREEN`, `$CYAN`, etc.).

## Agent Efficiency Guidelines

### DO — Maximise work per turn

| Rule | Why |
|------|-----|
| **Batch all reads in one turn.** View every file you need before writing any code. | Each turn has overhead; reading 5 files in 1 turn is 4× faster than 5 turns. |
| **Batch all writes in one turn.** Group edits to different files in a single response. | Parallel `edit` calls are independent and safe. |
| **Chain bash commands with `&&` or `;`.** `grep … && wc -l` is one tool call, not two. | Reduces round-trips and context accumulation. |
| **Read ranges, not whole large files.** Use `view_range` or targeted `grep -n` on files >200 lines. | The 1900-line `yt-x` is ~80 KB; full cat overflows inline output. |
| **Use `bash -n yt-x` before committing.** Catches syntax errors without running the script. | Fast sanity check, costs nothing. |
| **Run the full test suite in one command.** `bats tests/` covers all suites. | Never run individual suites unless diagnosing a specific failure. |
| **Make all independent tool calls in parallel.** Read files A, B, C simultaneously if they don't depend on each other. | Eliminates sequential blocking. |

### DON'T — Avoid token and request waste

| Anti-pattern | Better approach |
|--------------|-----------------|
| Reading a file in small ranges one at a time | Decide which ranges you need, request them all at once |
| Asking clarifying questions when context is clear | Act on what you know; note assumptions in commit message |
| Committing after every line changed | Commit at logical boundaries (one per issue/feature) |
| Running `shellcheck` separately from tests | `bats tests/ && shellcheck yt-x` in one bash call |
| Spinning up sub-agents for single-file edits | Use direct `edit` tool; agents add overhead for simple tasks |
| Checking `git status` after every edit | Check once before committing the batch |
| Using `cat yt-x` to read the whole file | Use `grep -n pattern yt-x` or `view` with `view_range` |
| Creating plan files for < 5-step tasks | Work in memory; write `plan.md` only for multi-phase work |

### Context budget heuristic

- **Explore phase:** stay under 20% of context window (reads + greps)
- **Implementation phase:** batch edits to use up to 70% of context window before committing
- **Verification phase:** run tests + shellcheck, fix any failures in the same turn where possible
- **Commit:** one `git add -A && git commit` call with full message; push in the same command



- **`%` in printf strings** — always quote dynamic content or use `%s` to avoid `printf` errors (see commit `4880033`).
- **Disown semantics** — the `DISOWN_STREAMING_PROCESS` flag forks mpv/vlc; any change to playback spawning must handle both the disowned and non-disowned paths.
- **Cookie extraction** — `PREFERRED_BROWSER` is passed directly to `yt-dlp --cookies-from-browser`; validate/sanitize before use.
- **Platform guards** — `PLATFORM` is set to `linux`, `mac`, `android`, or `windows`. Use it when adding platform-specific code.

## PR / Commit Guidelines

### Conventional Commits Format

```
<type>(<optional scope>): <short imperative summary>

[optional body — explain WHY, not what]

[optional footer: Closes #N, Co-authored-by: ...]
```

**Types:** `feat` · `fix` · `refactor` · `perf` · `security` · `docs` · `chore` · `test`

**Scopes** for this project: `playlist` · `preview` · `channels` · `config` · `ui` · `cli` · `download`

---

### What Makes a Good Atomic Commit

A commit is correctly sized when:

- It changes **one logical thing** — a reader can understand the full change without cross-referencing other files
- `shellcheck` passes before and after
- The script behaves identically before and after (for `refactor`/`perf` commits)
- Its subject line fits in 72 characters and uses the imperative mood

**Good examples:**
```
refactor(playlist): extract build_m3u8_playlist helper function

The identical M3U8-building block was copy-pasted four times across
Watch, Listen, Play All and Listen To All. Extract into a reusable
function to eliminate duplication.

Closes #14
```
```
perf(preview): replace O(n²) head/tail loop with jq array pass

download_preview_images used head -n $i | tail -n 1 inside a loop,
producing O(n²) pipe invocations. Replace with a single jq call that
emits all thumbnail URLs at once.

Closes #17
```
```
security(ui): quote jq --arg to prevent injection in channel names

Channel names were interpolated directly into jq filter strings,
allowing names containing " or | to corrupt queries. Switch to --arg.

Closes #21
```

**Bad examples (too large / too vague):**
```
# ❌ Multiple unrelated changes in one commit
refactor: clean up code and fix bugs and improve performance

# ❌ No context, vague scope
fix: misc fixes

# ❌ Entire file rewrite as a single commit (can't be reviewed meaningfully)
refactor: rewrite yt-x

# ❌ Formatting + logic change combined
refactor(playlist): fix logic and reformat whitespace
```

**Bad examples (too small / noise commits):**
```
# ❌ Fixing a typo in a comment warrants inclusion in the next
#    meaningful commit, not a commit of its own
chore: fix typo in comment on line 42

# ❌ Intermediate/WIP state should never be committed
wip: half-done extraction of open_in_editor
```

---

### Commit Granularity Rules

1. **One function extraction = one commit.** If you extract `open_in_editor()`, that is one commit — do not bundle it with unrelated logic changes.
2. **One duplication site ≠ one commit.** Eliminating all N copies of the same block IS one commit (it's one logical change).
3. **Refactor and bug-fix are separate commits** even if they touch the same function.
4. **Security hardening of the same class of bug** (e.g., adding `--arg` to all jq calls) can be one commit if scoped clearly.
5. **Never mix whitespace/formatting changes with logic changes** — reviewers cannot distinguish intent.

---

### Branch & PR Workflow

- Branch naming: `refactor/<issue-number>-<slug>` (e.g. `refactor/14-extract-m3u8-helper`)
- One PR per atomic task issue (or per tightly related group of 2–3 issues)
- PR title = commit subject of the squash merge
- Every PR must reference its issue: `Closes #N` in the PR body
- Squash-merge to keep `master` history clean; individual commits visible on the branch

### Reference Issues / Labels

- Reference issue numbers in commit footers: `Closes #N`
- Do not commit auto-generated files, editor configs, or OS artifacts
- Label conventions:
  - `epic` — abstract goal issue (never directly closed by a PR)
  - `task` + `refactor/perf/security/bug` — atomic work item, closed by one PR
  - `blocked` — add when a task cannot start until another closes
