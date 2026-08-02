# Changelog

All notable changes to this local setup are documented in this file.

## [0.4.4] - 2026-08-02

### Changed
- Renamed the second surface (MiniMax Coding Plan) variables `CODING_BASE_URL` / `CODING_KEYS` to `PLUS_URL` / `PLUS_KEYS`, and the `--surface` value `coding` to `plus`, across the launcher, `providers/minimax.sh`, README, and CLAUDE.md.
- The keypool proxy now orders the plus surface **first** (plus keys + plus URL ahead of the main Token Plan), spending the plus plan's quota before falling back.
- Single-key keypool providers (exactly one `AUTH_KEYS` entry and no `PLUS_KEYS`) auto-degrade: the gateway bypasses the Node keypool proxy and uses the single key directly via keychain auth, avoiding an unnecessary proxy process.

## [0.4.3] - 2026-08-02

### Removed
- Dropped the `start` / `stop` / `forget` / `rotate` subcommands and the per-provider "last used model" memory (`.state/last-model/<provider>`). Model selection now resolves purely from `--model` > `ANTHROPIC_MODEL` env > provider `MODEL`.

## [0.4.2] - 2026-08-02

### Added
- Management subcommands: `provider show`, `config show` / `config path`, `logs list` / `logs tail`, and `uninstall`.

## [0.4.1] - 2026-08-02

### Changed
- Renamed the launcher and its messages from `claude-gateway` to `crouter` (filenames unchanged).

## [0.4.0] - 2026-08-02

### Added
- Key-management subcommands for keypool providers: `add`, `rotate`, `remove`, `list keys` (Keychain-backed, TTY-entered secrets).

## [0.3.4] - 2026-08-01

### Changed
- Raised `EFFORT` to `max` (highest reasoning strength) for `deepseek` and `minimax`, matching what each API's `/anthropic` endpoint supports. DeepSeek thinking is ON by default at effort `high` and `max` is its ceiling; MiniMax-M3 supports the `thinking` block (`adaptive`) and `max` drives the deepest budget. Override per session with `claude-<provider> --effort <level>`. Verified `--effort max` injection for both with a mock Claude binary.

## [0.3.3] - 2026-08-01

### Added
- Reasoning effort control: a provider can set `EFFORT` (`low`|`medium`|`high`|`xhigh`|`max`), which the gateway passes to Claude Code as `--effort`. Override per session with `claude-<provider> --effort <level>`; invalid values are ignored with a warning. Defaults: `medium` for `antigravity-claude`/`deepseek`/`minimax`; unset for `antigravity` (Gemini effort is encoded in the model name, e.g. `gemini-3.6-flash-high`).

## [0.3.2] - 2026-08-01

### Added
- Remember last-used model per provider: the gateway stores the primary model chosen via `--model` or `ANTHROPIC_MODEL` in `.state/last-model/<provider>` and replays it on the next launch (precedence: `--model` > `ANTHROPIC_MODEL` env > remembered > provider `MODEL`). Reset with `claude-gateway forget <provider>`. Only the primary model is tracked; in-session `/model` switches inside Claude Code are not persisted.

## [0.3.1] - 2026-07-31

### Added
- Key pool & automatic failover: `AUTH_MODE="keypool"` + `AUTH_KEYS` starts a tiny dependency-free local proxy (`bin/keypool-proxy`) that rotates across multiple API keys on HTTP 429 (quota/rate-limit) or 401 (auth). Switching is transparent mid-session — no Claude Code restart required.
- `providers/minimax.sh` now ships in keypool mode: the Keychain item `codex-minimax-token-plan` is the first pool entry; add more keys via `AUTH_KEYS`, or a separate Coding Plan surface via optional `CODING_BASE_URL`/`CODING_KEYS`.
- Provider-agnostic: any provider can opt into keypool by setting `AUTH_MODE="keypool"` + `AUTH_KEYS`.

### Changed
- In keypool mode, `bin/claude-gateway` launches Claude Code as a child process (instead of `exec`) so the local proxy is torn down cleanly on session exit.

## [0.3.0] - 2026-07-31

### Added
- `deepseek` provider: DeepSeek V4 (Flash/Pro) via the official Anthropic-compatible endpoint `https://api.deepseek.com/anthropic`. No translation proxy required.
- `claude-deepseek` compatibility launcher (joins `claude-minimax`, `claude-antigravity`, `claude-antigravity-claude`).

### Changed
- Renamed the Gemini provider `antigravity-gemini` → `antigravity` so `claude-antigravity` maps 1:1 to the provider (antigravity = Gemini, `antigravity-claude` = Claude).
- Gemini model mapping now uses only `gemini-3.6-flash` with low/medium/high tiers: opus→high, sonnet→medium, haiku→low, subagents→medium.

## [0.2.0] - 2026-07-30

### Added
- bash/zsh shell autocompletion (`completions/claude-gateway.bash` and `.zsh`).
- Offline smoke test (`test/smoke.sh`).
- GitHub Actions CI running `shellcheck` + smoke test on push/PR.

### Changed
- `auth` env mode now reads the token via `printenv` instead of `eval` (no code-injection surface).
- Gateway `stop` uses `SIGTERM` → wait → `SIGKILL` fallback, with an `lsof` availability guard.
- Keychain lookups are cached to avoid repeated `security` calls.
- `cmd_doctor` uses explicit `if/else`; all sourced scripts gained `#!/bin/sh` shebangs.

## [0.1.0] - 2026-07-30

Initial release of the claude-gateway adapter framework.

### Changed

- Replaced the per-provider launcher scripts (`claude-minimax`, `claude-antigravity`, `claude-antigravity-claude`, `start/stop/status-antigravity`) with a single adapter framework: `bin/claude-gateway` + declarative `providers/*.sh`.
- Providers now declare only connection facts (endpoint, models, context, auth mode, hooks); the entry point owns secure key resolution, clean `env -i` launch, and lifecycle subcommands (`list`, `status`, `doctor`, `start`, `stop`).
- All absolute paths removed; the entry point locates the repository through symlink-safe self-resolution. Local overrides live in gitignored `config.sh` (see `config.example.sh`).
- Antigravity providers auto-start the local gateway via a `PRE_START` hook and wait for `/health`.

### Added

- A single directory for the Antigravity proxy, MiniMax launcher, gateway-control scripts, and usage documentation.
- Background start, stop, and health-check commands for the Antigravity gateway.
- A dedicated Antigravity Claude launcher with Claude-specific model aliases and a 200K context window.

### Fixed

- Antigravity start command now runs `npm start` from the proxy source directory.
- Antigravity stop command now targets only the Node process listening on port 18080.
- Antigravity Claude Code sessions now use Gemini's 1,048,576-token context window instead of the gateway fallback of 200,000 tokens.
- MiniMax Claude Code sessions now use MiniMax M3's 1,048,576-token context window instead of the gateway fallback of 200,000 tokens.
- Gemini launcher no longer exposes raw gateway model discovery, preventing Claude models from inheriting Gemini's 1M context configuration.
