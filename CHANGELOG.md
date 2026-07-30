# Changelog

All notable changes to this local setup are documented in this file.

## [Unreleased]

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
