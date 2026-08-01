# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- **Run Smoke Tests**: `./test/smoke.sh`
- **Install Local Binary & Compatibility Launchers**: `./install.sh`
- **Lint Shell Scripts**: `shellcheck bin/crouter bin/claude-antigravity bin/claude-antigravity-claude bin/claude-minimax install.sh test/smoke.sh providers/*.sh providers/lib/*.sh`
- **Run Framework Entry Point**: `./bin/crouter list` (or `doctor`, `add <provider>`, `remove <provider> --name <service>`, `list keys <provider>`)

## Architecture & Code Structure

`crouter` is a POSIX `/bin/sh` adapter framework that provides a single, portable entry point to launch Claude Code against multiple Anthropic-compatible LLM providers.

### Execution Flow

1. **Self-Location**: `bin/crouter` dynamically resolves its absolute path following symlinks using `readlink` with `CDPATH=` to ensure safety across environments.
2. **Configuration & Provider Contracts**: Sourcing `config.sh` (gitignored local overrides) followed by `providers/<name>.sh`. Providers set declarative variables:
   - `BASE_URL`, `MODEL`, `CONTEXT_TOKENS`, `EFFORT` (reasoning effort: `low`|`medium`|`high`|`xhigh`|`max`, passed to Claude Code as `--effort`)
   - Model aliases: `MODEL_OPUS`, `MODEL_SONNET`, `MODEL_HAIKU`, `MODEL_SUBAGENT`
   - `AUTH_MODE`: `keychain`, `env`, `command`, `static`, `none`, or `keypool`
   - `AUTH_REFERENCE`: Keychain service name, environment variable name, or command
   - Lifecycle hooks: `PRE_START`, `POST_STOP`, `HEALTH_CHECK_URL`
3. **Lifecycle Hooks**: `PRE_START` hook runs prior to launch (e.g. `antigravity_ensure_gateway` auto-starts the local proxy and polls `/health`).
4. **Credential Resolution**: `AUTH_TOKEN` is resolved at launch time without exposing secrets in process environments or disk storage.
5. **Isolated Execution**: Launches Claude Code via `env -i` with a clean, terminal-safe minimal environment (`HOME`, `PATH`, `TERM`, `LANG`, etc.) and injected `ANTHROPIC_*` environment variables.

### Subcommands

Subcommands are flat: `crouter <verb> [args]`. Verbs: `<provider>` (default — launch), `list [keys [provider]]`, `doctor [provider]`, `add <provider> [--surface main|coding] [--name <service>]`, `remove <provider> --name <service> [--surface main|coding] [-y]`. The three key-management verbs (`add` / `remove` / `list keys`) operate on a keypool provider's `AUTH_KEYS` / `CODING_KEYS` list and the matching macOS Keychain entries; `add` reads the secret from `/dev/tty` so it never appears in argv or shell history.

### File Layout

- `bin/crouter`: Core entry point owning launcher execution, auth lookup, key-management commands, and environment isolation.
- `bin/claude-*`: Compatibility launchers delegating to specific provider commands.
- `providers/`: Provider definitions (`minimax.sh`, `antigravity.sh` for Gemini, `antigravity-claude.sh` for Claude, `deepseek.sh`).
- `providers/lib/`: Shared provider utilities (`antigravity-common.sh` for proxy management).
- `install.sh`: Creates executable symlinks in `$INSTALL_DIR` (`~/.local/bin`) and copies `config.example.sh` to `config.sh`.
- `test/smoke.sh`: Hermetic offline smoke test suite (with stubs for `security(1)` / `node(1)` so key-management paths run without a real Keychain or Node).