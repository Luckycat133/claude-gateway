# claude-gateway

A small adapter framework for launching Claude Code against multiple Anthropic-compatible providers from one command. Providers only declare *how to connect*; the single entry point owns *how to launch safely and portably*.

No API key is ever stored in this repository. Keys are resolved at launch time from macOS Keychain, environment variables, or a user-supplied command.

## Layout

```text
ai-coding-gateways/
├── bin/
│   └── claude-gateway             # The only entry point
├── providers/
│   ├── minimax.sh                 # MiniMax M3 (China endpoint)
│   ├── deepseek.sh                # DeepSeek V4 (Flash/Pro) via /anthropic endpoint
│   ├── antigravity.sh             # Gemini via local Antigravity proxy
│   ├── antigravity-claude.sh      # Claude via local Antigravity proxy
│   └── lib/antigravity-common.sh  # Shared gateway lifecycle helpers
├── config.example.sh              # Copy to config.sh (gitignored)
├── install.sh                     # Symlink claude-gateway into ~/.local/bin
├── antigravity-claude-proxy/      # Third-party proxy checkout; NOT committed
└── logs/                          # Runtime logs; gitignored
```

## Install

```sh
./install.sh          # symlinks claude-gateway into ~/.local/bin, creates config.sh
```

For backward compatibility, the installer also provides these equivalent shortcuts:

```sh
claude-minimax                # claude-gateway minimax
claude-antigravity            # claude-gateway antigravity
claude-antigravity-claude     # claude-gateway antigravity-claude
claude-deepseek              # claude-gateway deepseek
```

To use the Antigravity providers, also set up the third-party proxy (see below). MiniMax needs no extra setup beyond the Keychain key.

## Usage

```sh
claude-gateway list                     # available providers
claude-gateway minimax                  # Claude Code via MiniMax M3
claude-gateway antigravity             # Claude Code via Antigravity Gemini
claude-gateway antigravity-claude       # Claude Code via Antigravity Claude
claude-gateway deepseek                  # Claude Code via DeepSeek V4 (Flash/Pro)
claude-gateway status [provider]        # auth + health at a glance
claude-gateway doctor [provider]        # environment diagnostics
claude-gateway start antigravity       # run PRE_START hook only (start gateway)
claude-gateway stop antigravity        # run POST_STOP hook only (stop gateway)
```

Extra arguments after the provider name are passed straight to Claude Code. Per-session model override:

```sh
ANTHROPIC_MODEL=gemini-3.6-flash-high claude-gateway antigravity
```

### Remember the last model per provider

The gateway remembers the primary model you pick for each provider and reuses it next launch, so you don't re-pass `--model` every time.

- An explicit choice wins and is stored: `--model <id>` (or `ANTHROPIC_MODEL=<id>`).
- Next launch without `--model` replays the remembered model.
- Reset a provider's memory: `claude-gateway forget <provider>`.
- No memory yet → falls back to the provider's `MODEL`.

Only the **primary** model is remembered. Switching models mid-session with `/model` inside Claude Code is not persisted — the gateway only controls the launch-time default.

## How it works

The entry point:

1. Resolves its own location through symlinks, so no absolute path is hardcoded anywhere.
2. Sources `config.sh` (local, gitignored), then the selected `providers/<name>.sh`.
3. Runs the provider's optional `PRE_START` hook (for Antigravity this auto-starts the local gateway and waits for `/health`).
4. Resolves the credential according to `AUTH_MODE` — the secret exists only in the launcher process.
5. Launches Claude Code with `env -i` and a minimal, terminal-safe environment (`HOME`, `PATH`, locale, terminal capabilities), so stray shell variables such as `NO_COLOR` cannot leak in.
6. Injects endpoint, default model, model aliases (opus/sonnet/haiku/subagent), context window, and any provider `EXTRA_ENV`.

## Adding a provider

Create `providers/<name>.sh` — no changes to the entry point are needed:

```sh
PROVIDER_NAME="openrouter"
BASE_URL="https://openrouter.ai/api"        # Anthropic-compatible endpoint
MODEL="some/default-model"
CONTEXT_TOKENS="200000"
MODEL_OPUS=""                               # optional; default to MODEL
MODEL_SONNET=""
MODEL_HAIKU=""
MODEL_SUBAGENT=""
AUTH_MODE="keychain"                        # keychain | env | command | static | none | keypool
AUTH_REFERENCE="my-openrouter-key"          # keychain item / env var name / command
EXTRA_ENV=""                                # one KEY=VALUE per line
PRE_START=""                                # optional lifecycle hooks
POST_STOP=""
HEALTH_CHECK_URL=""                         # used by status/doctor
```

`AUTH_MODE` semantics:

| Mode | `AUTH_REFERENCE` means | Example |
| --- | --- | --- |
| `keychain` | macOS Keychain generic-password service name | `codex-minimax-token-plan` |
| `env` | Name of an environment variable | `OPENROUTER_API_KEY` |
| `command` | A command whose stdout is the token | `pass show openrouter` |
| `static` | The literal (non-secret) token | `local-antigravity-proxy` |
| `none` | No credential injected | |
| `keypool` | Space-separated Keychain service names (`AUTH_KEYS`); a local proxy rotates across them on 429/401 | `codex-minimax-token-plan` |

## Key pool & automatic failover

Some providers let you hold several API keys (e.g. multiple MiniMax plans, or a
pay-as-you-go key plus a Coding Plan). Set `AUTH_MODE="keypool"` and list the
Keychain service names in `AUTH_KEYS` (space-separated). At launch the gateway
resolves every key, starts a tiny local proxy (`bin/keypool-proxy`), and points
Claude Code at the proxy instead of the real endpoint.

The proxy forwards each request and, on a quota/rate-limit error (HTTP **429**)
or an auth error (**401**), transparently retries with the next key — including
**mid-session, with no interruption** to the running Claude Code session. When all
keys on a surface are exhausted it falls through to the next surface (if
configured), otherwise it returns the upstream error.

### MiniMax example

`providers/minimax.sh` ships in keypool mode:

```sh
AUTH_MODE="keypool"
AUTH_KEYS="codex-minimax-token-plan"   # append more Keychain service names here
# Optional second surface (MiniMax Coding Plan). Its endpoint and supported
# models differ from the Token Plan; fill these once you have the key(s):
# CODING_BASE_URL="https://.../anthropic"
# CODING_KEYS="minimax-coding-1 minimax-coding-2"
```

Add a key (no shell-history exposure):

```sh
read -s "K?Paste MiniMax key: "; echo
security add-generic-password -U -a "$USER" -s "minimax-2" -w "$K"; unset K
```

then append `minimax-2` to `AUTH_KEYS`. The proxy tries every key on the API
surface first, then every key on the Coding Plan surface.

Notes:
- The local proxy listens on `127.0.0.1` only and is torn down when the session ends.
- `keypool` is provider-agnostic; any provider can opt in via `AUTH_MODE="keypool"` + `AUTH_KEYS`.

## Providers

### MiniMax Token Plan

China endpoint `https://api.minimaxi.com/anthropic`, default `MiniMax-M3`, 1,048,576-token input context. It runs in `AUTH_MODE="keypool"`: the Keychain item `codex-minimax-token-plan` is the first entry in `AUTH_KEYS`, and you can add more keys, or a separate Coding Plan surface via `CODING_BASE_URL`/`CODING_KEYS` — see [Key pool & automatic failover](#key-pool--automatic-failover). To set or rotate a key without shell-history exposure:

```sh
read -s "MINIMAX_TOKEN_PLAN_KEY?Paste MiniMax Token Plan Key: "
echo
security add-generic-password -U -a "$USER" -s "codex-minimax-token-plan" -w "$MINIMAX_TOKEN_PLAN_KEY"
unset MINIMAX_TOKEN_PLAN_KEY
```

### DeepSeek V4

Anthropic-compatible endpoint `https://api.deepseek.com/anthropic`, default `deepseek-v4-flash`, 1,000,000-token context. The key is read from the Keychain item `deepseek-api-key`. To set or rotate it without shell-history exposure:

```sh
read -s "DEEPSEEK_KEY?Paste DeepSeek API key: "
echo
security add-generic-password -U -a "$USER" -s "deepseek-api-key" -w "$DEEPSEEK_KEY"
unset DEEPSEEK_KEY
```

Model mapping (1M context):

| Claude Code selection | DeepSeek model |
| --- | --- |
| Default | `deepseek-v4-flash` |
| `/model opus` | `deepseek-v4-pro` |
| `/model sonnet`, `/model haiku`, subagents | `deepseek-v4-flash` |

Note: the former `deepseek-chat` / `deepseek-reasoner` names were deprecated on 2026-07-24; use `deepseek-v4-flash` / `deepseek-v4-pro`. Prefer the Keychain setup above. To instead read the key from an environment variable, change the provider to `AUTH_MODE="env"` and `AUTH_REFERENCE="DEEPSEEK_API_KEY"`, then `export DEEPSEEK_API_KEY=...`.

### Antigravity (Gemini / Claude)

Both providers talk to a local proxy bound to `127.0.0.1:18080`. The proxy is the third-party open-source project [antigravity-claude-proxy](https://github.com/badrisnarayanan/antigravity-claude-proxy) (MIT). Its source is **not** committed to this repository — set it up once:

```sh
# From the repository root (or anywhere; see ANTIGRAVITY_PROXY_DIR below)
git clone https://github.com/badrisnarayanan/antigravity-claude-proxy.git
cd antigravity-claude-proxy
npm install
```

If you clone it somewhere else or change the port, point the framework at it in `config.sh`:

```sh
ANTIGRAVITY_PROXY_DIR="$HOME/src/antigravity-claude-proxy"
ANTIGRAVITY_PORT=18080
```

The proxy signs in with a Google account on first run — follow its own README for account setup. Keep it updated with `git pull && npm install`.

Launching either Antigravity provider auto-starts the gateway if it is not running (`PRE_START` hook waits for `/health`); `claude-gateway stop <provider>` shuts it down.

Gemini mapping (1M context):

| Claude Code selection | Antigravity model |
| --- | --- |
| Default | `gemini-3.6-flash-medium` |
| `/model opus` | `gemini-3.6-flash-high` |
| `/model sonnet` | `gemini-3.6-flash-medium` |
| `/model haiku` | `gemini-3.6-flash-low` |
| subagents | `gemini-3.6-flash-medium` |

Claude mapping (200K context): default and `/model opus` → `claude-opus-4-6-thinking`; `/model sonnet`, `/model haiku`, and subagents → `claude-sonnet-4-6`.

Do not switch between Gemini and Claude models inside one session — their thinking signatures are incompatible. Start a new session with the matching provider instead.

The Antigravity proxy is an unofficial integration. Do not use it with a primary Google account, sensitive source code, or production credentials.

## What to commit

| Content | Commit? |
| --- | --- |
| Launcher framework, provider examples, README | Yes |
| `config.example.sh` | Yes |
| Your real `config.sh` | No (gitignored) |
| Keychain item names, env var names | OK |
| API keys, Google account data, logs, account files | Never |

## Troubleshooting

- `claude-gateway doctor` checks the Claude binary, config, curl/keychain availability, per-provider auth, and gateway health.
- Antigravity gateway logs: `logs/antigravity-proxy.log`.
- MiniMax 401: confirm the Keychain item holds a China Token Plan key.
- If an Antigravity Claude model is quota-limited, use `antigravity` until it resets.

## Version & autocompletion

- Version is tracked in the `VERSION` file. `claude-gateway --version` prints it.
- Shell autocompletion: source `completions/claude-gateway.bash` (bash) or `completions/claude-gateway.zsh` (zsh) from your shell rc.

## Development

- `sh test/smoke.sh` runs a minimal offline smoke test (no keychain or network required).
- On push/PR, GitHub Actions runs `shellcheck` on all scripts and the smoke test.
