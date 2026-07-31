# Changelog

All notable changes to this local setup are documented in this file.

## [Unreleased]

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
