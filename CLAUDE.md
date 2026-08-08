# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- **Run Smoke Tests**: `./test/smoke.sh`
- **Install Local Binary & Compatibility Launchers**: `./install.sh`
- **Lint Shell Scripts**: `shellcheck bin/crouter bin/crouter-compat install.sh test/smoke.sh providers/*.sh lib/*.sh`
- **Run Framework Entry Point**: `./bin/crouter list` (or `doctor`, `add <provider>`, `remove <provider> --name <service>`, `list keys <provider>`, `all`)

## Architecture & Code Structure

`crouter` is a POSIX `/bin/sh` adapter framework that provides a single, portable entry point to launch Claude Code against multiple Anthropic-compatible LLM providers.

### Execution Flow

1. **Self-Location**: `bin/crouter` dynamically resolves its absolute path following symlinks using `readlink` with `CDPATH=` to ensure safety across environments.
2. **Configuration & Provider Contracts**: Sourcing `config.sh` (gitignored local overrides) followed by `providers/<name>.sh`. Providers set declarative variables:
   - `BASE_URL`, `MODEL`, `CONTEXT_TOKENS`, `EFFORT` (reasoning effort: `low`|`medium`|`high`|`xhigh`|`max`, passed to Claude Code as `--effort`)
   - `CONTEXT_TOKENS`: upstream model's context window in tokens. Sets `CLAUDE_CODE_MAX_CONTEXT_TOKENS` at launch. If omitted, the variable is not injected and Claude Code uses its own default.
   - Model aliases: `MODEL_OPUS`, `MODEL_SONNET`, `MODEL_HAIKU`, `MODEL_SUBAGENT`
   - `AUTH_MODE`: `keychain`, `env`, `command`, `static`, `none`, `keypool`, `surfaces`, or `native`
   - `AUTH_REFERENCE`: Keychain service name, environment variable name, or command
   - `AUTH_KEYCHAIN_FALLBACK`: optional Keychain service name used when `AUTH_MODE=env` and the env var is unset (lets a provider accept both "export the key" and "store it in the Keychain" without a second AUTH_MODE).
   - Explicit billing surfaces (`AUTH_MODE=surfaces`): `PLAN_URL`, `PLAN_AUTH_TYPE`, `PLAN_KEY_ENV`, `PLAN_KEYS`, and `PLAN_MODEL*`; plus the corresponding `API_*` fields. Every credential stays bound to its URL, auth header, and per-tier model map.
   - Dual-source (`anthropic`): `DEFAULT_URL`, `DEFAULT_AUTH_TYPE`, `DEFAULT_TOKEN_ENV`, `DEFAULT_TOKEN_ENV_FALLBACK` for the preferred account; `API_URL`, `API_AUTH_TYPE`, `API_KEY_ENV`, `API_KEY_REF` for the fallback key. `is_dual_source()` detects it; `load_provider()` must reset every optional field or values leak across providers.
   - Native cloud backends: `NATIVE_BACKEND`, `EXTRA_ENV`, and an allowlist in `PASSTHROUGH_ENV`.
   - Session assets: `ASSET_PROFILE` and plan/API-specific plugin directories. `lib/assets.sh` creates a mode-600 MCP config and activates only the current provider's namespaced skills.
   - Lifecycle hooks: `PRE_START`, `POST_STOP`, `HEALTH_CHECK_URL`
3. **Lifecycle Hooks**: `PRE_START` hook runs prior to launch (e.g. `antigravity_ensure_gateway` auto-starts the local proxy and polls `/health`).
4. **Credential Resolution**: Credentials are resolved at launch time without printing secrets. Surface providers build explicit candidates; dual-source providers go through `resolve_dual_source()` and set `_AUTH_SCHEME` (`bearer` / `x-api-key`). `lib/launch.sh` injects only the matching header env. Managed MCP secrets live in a temporary mode-600 file deleted at exit.
   When both surfaces exist, `start_dual_failover()` fronts them with `bin/keypool-proxy` in candidate mode so 401/402/403/429 rotation happens mid-session; `launch.sh` treats any non-empty `KEYPOOL_URL` as "a local proxy owns auth".
5. **Isolated Execution**: Launches Claude Code via `env -i` with a clean, terminal-safe minimal environment (`HOME`, `PATH`, `TERM`, `LANG`, etc.) and injected `ANTHROPIC_*` environment variables.

### Subcommands

Subcommands are flat: `crouter <verb> [args]`. Verbs: `<provider> [<model>]` (default launch), `list [keys [provider]]`, `doctor [provider]`, `add <provider> [--surface plan|api] [--name <service>]`, `remove <provider> --name <service> [--surface plan|api] [-y]`, and `all`. Key-management commands operate on `PLAN_KEYS` / `API_KEYS` for surface providers and retain `AUTH_KEYS` / `PLUS_KEYS` compatibility. `all` fronts HTTP providers behind a namespaced local gateway; native Bedrock/Vertex and provider session assets require direct launches.

### File Layout

- `bin/crouter`: Core entry point owning launcher execution, auth lookup, key-management commands, environment isolation, and the `all` unified-gateway command.
- `bin/gateway`: Dependency-free Node Anthropic-protocol router used by `crouter all`. Reads a routes JSON (one entry per provider: `prefix`, `candidates[]`, `models`), serves `GET /v1/models`, and routes authenticated `POST /v1/messages` by the first `<provider>/` model segment. Each candidate owns its URL, auth token/header type, and tier `model_map`; the gateway fails over on 401/402/403/429.
- `bin/keypool-proxy`: Local failover proxy. Candidate mode accepts explicit `{url,type,token,model_map,label}` entries, preserving endpoint/header/model ownership and rotating on 401/402/403/429. Managed instances require a random session token.
- `bin/claude-*`: Compatibility launchers — symlinks to `bin/crouter-compat` that delegate to specific provider commands (the provider is derived from the invoked name). `install.sh` generates one per file in `providers/`, so adding a provider needs no edit there.
- `providers/`: Audited first-party Anthropic-compatible, native-cloud, and explicitly named local-proxy contracts. Domestic providers use plan/API surfaces; unsupported guessed OpenAI/Baichuan routes are excluded.
- `lib/`: Shared shell modules (`provider.sh`, `auth.sh`, `key-mgmt.sh`, `assets.sh`, `launch.sh`), `antigravity-common.sh`, and dependency-free JSON builders/renderers (`route-build.js`, `provider-assets.js`).
- `install.sh`: Creates executable symlinks in `$INSTALL_DIR` (`~/.local/bin`) and copies `config.example.sh` to `config.sh`.
- `test/`: Hermetic offline contract, proxy, lifecycle, provider-matrix, native-backend, and asset-isolation tests. Run all `test/*.sh`, not only the legacy smoke entry point.
