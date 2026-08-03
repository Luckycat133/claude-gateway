# Changelog

All notable changes to this local setup are documented in this file.

## [0.4.11] - 2026-08-03

### Added
- **MiniMax auto-MCP wiring.** `crouter minimax` auto-registers the two official MiniMax MCP servers (`minimax-coding` = `web_search` + `understand_image`, `minimax-gen` = `text_to_image` / `generate_video` / `music_generation` / `voice_clone` / `voice_design`) using the official `uvx` method, and installs the `minimax-multimodal-toolkit` skill via the official **Claude Code plugin method** (`claude plugin marketplace add https://github.com/MiniMax-AI/skills` + `claude plugin install minimax-skills`) — but only when a Token Plan key (`codex-minimax-token-plan` in Keychain) is present. All three are registered **globally** (`claude mcp add -s user`, `~/.claude` plugins), never project-scoped. Idempotent; already-registered servers / installed skills are skipped. Gated by `MINIMAX_AUTO_MCP` (default 1) and `MINIMAX_AUTO_SKILL` (default 1) in `config.sh`; set to `0` to disable. Wiring is driven by `providers/minimax.sh`'s `PRE_START` hook → `bin/minimax-mcp-autosetup`. Missing dependencies are auto-installed using the official methods: `uvx` (astral.sh installer) and `mmx-cli` (`npm install -g`), and `mmx auth login` runs automatically with the Token Plan key so the skill is usable immediately. Note: the `mcp==1.9.4` pin on both MCP `uvx` commands is a compatibility workaround (MiniMax's packages import the removed `mcp.server.fastmcp` path under mcp 2.x); it can be dropped once MiniMax pins its SDK dependency.

### Removed
- `bin/minimax-mcp-bridge` (obsoleted by the official-`uvx` auto-wiring above).

## [0.4.10] - 2026-08-03

### Added
- **MiniMax auto-MCP wiring.** `crouter minimax` auto-registers the two official MiniMax MCP servers (`minimax-coding` = `web_search` + `understand_image`, `minimax-gen` = `text_to_image` / `generate_video` / `music_generation` / `voice_clone` / `voice_design`) and installs the `minimax-multimodal-toolkit` skill via the official `uvx` method — but only when a Token Plan key (`codex-minimax-token-plan` in Keychain) is present. Idempotent; already-registered servers / installed skills are skipped. Gated by `MINIMAX_AUTO_MCP` (default 1) and `MINIMAX_AUTO_SKILL` (default 1) in `config.sh`; set to `0` to disable. Wiring is driven by `providers/minimax.sh`'s `PRE_START` hook → `bin/minimax-mcp-autosetup`.

## [0.4.9] - 2026-08-02

### Added
- Three new providers: **`anthropic`** (Anthropic Claude, `https://api.anthropic.com`, default `claude-sonnet-4`), **`openai`** (GPT via OpenAI's Anthropic-compatible `https://api.openai.com/v1/messages`, default `gpt-4o`), and **`openrouter`** (`https://openrouter.ai/api/v1`, default `anthropic/claude-sonnet-4`, with the mandatory empty `ANTHROPIC_API_KEY` in `EXTRA_ENV`).
- **Dual-source auth: default account first, API key as fallback.** `anthropic` and `openai` declare two credential surfaces instead of a single `AUTH_MODE` — `DEFAULT_URL`/`DEFAULT_AUTH_TYPE`/`DEFAULT_TOKEN_ENV`(`_FALLBACK`) for the preferred account and `API_URL`/`API_AUTH_TYPE`/`API_KEY_ENV`/`API_KEY_REF` for the metered key. crouter always spends the default account's included quota first and rotates to the API key on **401/429**. For `anthropic` the default account is the Claude subscription OAuth token (`claude setup-token` → `CLAUDE_CODE_OAUTH_TOKEN`, or `ANTHROPIC_AUTH_TOKEN`); for `openai` it is an optional self-configured gateway (`OPENAI_DEFAULT_URL` / `OPENAI_DEFAULT_TOKEN`).
- Rotation works in **both** launch paths, not just at start-up: `crouter <provider>` fronts the two surfaces with `bin/keypool-proxy` in the new **candidate mode** (`KEYPOOL_CANDIDATES` JSON, per-candidate URL + header shape), and `crouter all` makes each surface a candidate on the provider's route. With only one surface configured, the direct connection is used and no proxy is started.
- `crouter list` reports `dual` / `apikey` for these providers; `crouter doctor` reports which credentials are actually live (`auth:ok(default+api)`); `crouter provider <name>` prints the full surface layout (URLs, header types, env/keychain names) with no secrets.

### Changed
- `bin/gateway` routes now hold an ordered `candidates[]` array (each with its own `url`, `auth{type,token}` and `extra_env`) instead of a single `auth` object. Failing over on 401/429 is now one mechanism shared by keypool key rotation and dual-source fallback; keypool routes simply list every key as its own candidate.
- `install.sh` derives the `claude-<provider>` compatibility shortcuts from the contents of `providers/`, so adding a provider no longer requires editing the install script. Repo-local `bin/claude-*` symlinks added for `ollama`, `anthropic`, `openai`, `openrouter`.
- Shell completions now offer provider names (and `all`) at the first argument position, not only the subcommand verbs.

### Fixed
- **Auth header shape is no longer guessed.** `lib/launch.sh` used to export *both* `ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN` with the same value. An Anthropic subscription OAuth token is only valid as `Authorization: Bearer`, so sending it as `x-api-key` gets it rejected. Dual-source providers now set `_AUTH_SCHEME` during resolution and only the matching env var is injected; legacy providers keep the previous both-headers behavior.
- `load_provider()` did not reset `AUTH_KEYS`, `PLUS_URL`, `PLUS_KEYS`, `EFFORT` or any of the new dual-source variables, so values leaked between providers when several were loaded in one shell (`crouter doctor`, `crouter all`). All optional contract fields are now cleared before sourcing.
- `check_auth()` returned "ok" for dual-source providers with no credentials at all (they default to `AUTH_MODE=none`). It now requires at least one usable surface.
- `bin/keypool-proxy` / `bin/gateway` no longer send an empty credential header when a `none`-auth route has no dummy token.

### Verified
- `test/smoke.sh` extended to 29 checks, including a real end-to-end failover run against a mock upstream: the proxy sends `Authorization: Bearer` first, receives 429, then retries with `x-api-key` only and gets HTTP 200 — asserting the exact header sequence `bearer,x-api-key` (never both on one request). The same failover was verified through `bin/gateway`, and all four direct-launch permutations (both surfaces / default only / API key only / none) were checked against a stub `claude` binary.

## [0.4.8] - 2026-08-02

### Fixed
- `crouter all` (unified gateway) was broken for `none`-auth providers (ollama): `build_all_routes` split `EXTRA_ENV` on `;` only, but ollama's `EXTRA_ENV` is newline-separated, so the dummy token came out as `"ollama\nANTHROPIC_API_KEY=ollama"`. The gateway injected that as an invalid multi-line `x-api-key` header and the backend connection returned an empty reply. Now split on both newline and `;`, and forward the full `EXTRA_ENV` set as headers (mirroring `launch.sh`). The ollama catalog is also enriched from `ollama list` so `/model` can list locally-pulled models. Verified end-to-end against real ollama (`qwen3.5:2b`, HTTP 200) and real DeepSeek (`deepseek-v4-flash` via keypool, HTTP 200).

## [0.4.7] - 2026-08-02

### Added
- `crouter all`: a unified gateway that fuses every provider behind one fixed `ANTHROPIC_BASE_URL`. It starts a local Anthropic-protocol router (`bin/gateway`, dependency-free Node) and launches Claude Code against it, so providers can be switched live from inside Claude Code via `/model <provider>/<model>` (e.g. `/model ollama/qwen3.5:2b`). The router serves `GET /v1/models` (combined, namespaced catalog) and `POST /v1/messages` (route by model prefix to the right backend with that backend's own auth; keypool providers still rotate keys on 429). The gateway listens on `127.0.0.1:${CROUTER_GATEWAY_PORT:-18799}` and is reaped when Claude Code exits. The individual per-provider commands remain untouched.

## [0.4.6] - 2026-08-02

### Added
- Added an `ollama` provider (`providers/ollama.sh`) that runs Claude Code against local or cloud open-weight models through Ollama's native Anthropic-compatible Messages API (Ollama v0.14.0+). No translation proxy and no API key are needed — `BASE_URL` points at `http://localhost:11434` and `AUTH_MODE="none"` injects the dummy `ANTHROPIC_AUTH_TOKEN=ollama` (Ollama ignores it) via `EXTRA_ENV`. `PRE_START` verifies the Ollama service is up; `HEALTH_CHECK_URL` enables `doctor` checks. `install.sh` now also links `claude-ollama`. Verified end-to-end with `qwen3.5:2b` on 2026-08-02 (no proxy, no key).

### Changed
- `crouter <provider> <model>` is now shorthand for `--model <model>`: the first bare positional argument before any flag is treated as the model and is stripped from the args forwarded to Claude Code (so `crouter ollama qwen3.5:2b -p "hi"` works, and a flag's value such as `-p "x"` is never misread as the model). Explicit `--model` still wins. Applies to every provider through the shared `cmd_run` dispatch.

## [0.4.5] - 2026-08-02

### Changed
- Deduplicated the four compatibility launchers (`bin/claude-minimax`, `claude-antigravity`, `claude-deepseek`, `claude-antigravity-claude`) into a single shared `bin/crouter-compat` that derives the provider from the invoked name (strips the `claude-` prefix). The four launchers are now symlinks to it, eliminating ~45 lines of duplicated symlink-resolution boilerplate. `install.sh` links each shortcut to `crouter-compat`.

### Internal
- Extracted the cross-provider helper logic out of the ~900-line `bin/crouter` into sourced `lib/` modules with no behavior change: `lib/provider.sh` (provider lookup/load with contract reset), `lib/auth.sh` (keychain state, keypool start/check, health), `lib/key-mgmt.sh` (key add/remove/list + keychain I/O), and `lib/launch.sh` (the `env -i` isolated Claude Code launch, incl. keypool vs direct-auth branches, effort injection, and `EXTRA_ENV`). `bin/crouter` now sources these four modules and drops from ~906 to ~405 lines. Verified equivalent via `test/smoke.sh` and a dedicated launch-env harness (alias/model vars, `EXTRA_ENV`, minimal terminal env, and keypool `keypool-local` creds all match the previous inline code).

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
- Renamed the launcher and its messages from `claude-gateway` to `crouter`. The binary file `bin/claude-gateway` was renamed to `bin/crouter` in a follow-up fix commit that completed the rename (the initial 0.4.1 commit only rewrote the string references).

## [0.4.0] - 2026-08-02

### Added
- Key-management subcommands for keypool providers: `add`, `rotate`, `remove`, `list keys` (Keychain-backed, TTY-entered secrets).

### Fixed
- `crouter <provider> --version` (and `--help`) no longer spins up the Node keypool proxy — auth/proxy startup is bypassed for help/version queries and torn down cleanly.

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
- bash/zsh shell autocompletion (`completions/crouter.bash` and `.zsh`).
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
