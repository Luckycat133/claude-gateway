# crouter

A small adapter framework for launching Claude Code against multiple Anthropic-compatible providers from one command. Providers only declare *how to connect*; the single entry point owns *how to launch safely and portably*.

No API key is ever stored in this repository. Keys are resolved at launch time from macOS Keychain, environment variables, or a user-supplied command.

## Layout

```text
crouter/
├── bin/
│   └── crouter             # The only entry point
├── providers/
│   ├── anthropic.sh               # Anthropic Claude (subscription OAuth -> API key)
│   ├── openai.sh                  # OpenAI GPT via the Anthropic-compatible Messages API
│   ├── openrouter.sh              # OpenRouter unified gateway
│   ├── minimax.sh                 # MiniMax M3 (China endpoint)
│   ├── deepseek.sh                # DeepSeek V4 (Flash/Pro) via /anthropic endpoint
│   ├── antigravity.sh             # Gemini via local Antigravity proxy
│   ├── antigravity-claude.sh      # Claude via local Antigravity proxy
│   ├── ollama.sh                  # Ollama local/cloud models (native Anthropic API)
│   └── lib/antigravity-common.sh  # Shared gateway lifecycle helpers
├── config.example.sh              # Copy to config.sh (gitignored)
├── install.sh                     # Symlink crouter into ~/.local/bin
├── antigravity-claude-proxy/      # Third-party proxy checkout; NOT committed
└── logs/                          # Runtime logs; gitignored
```

## Install

```sh
./install.sh          # symlinks crouter into ~/.local/bin, creates config.sh
```

> **If you move or rename the repo directory**, the existing symlinks in `~/.local/bin` keep pointing at the old path and break (`command not found`). Re-run `./install.sh` to regenerate them. A stale shell may also cache the old command — run `rehash` (zsh) or open a new terminal.

For backward compatibility, the installer also provides these equivalent shortcuts:

```sh
claude-minimax                # crouter minimax
claude-antigravity            # crouter antigravity
claude-antigravity-claude     # crouter antigravity-claude
claude-deepseek              # crouter deepseek
claude-ollama                # crouter ollama
```

To use the Antigravity providers, also set up the third-party proxy (see below). MiniMax needs no extra setup beyond the Keychain key. Ollama needs no proxy or key — it serves the Anthropic API locally on port 11434 (see the Ollama section below).

## Usage

The first bare word after a provider name selects the model (e.g. `crouter ollama qwen3.5:2b`).

```sh
crouter list                     # available providers
crouter minimax                  # Claude Code via MiniMax M3
crouter antigravity             # Claude Code via Antigravity Gemini
crouter antigravity-claude       # Claude Code via Antigravity Claude
crouter deepseek                  # Claude Code via DeepSeek V4 (Flash/Pro)
crouter ollama                    # Claude Code via Ollama (local/cloud models)
crouter doctor [provider]        # environment diagnostics
```

Extra arguments after the provider name are passed straight to Claude Code. Per-session model override — the model may be a bare positional (the first word before any flag) or an explicit flag:

```sh
crouter ollama qwen3.5:2b                        # positional model (short form)
crouter ollama qwen3.5:2b -p "hi"                # positional model + flags
crouter antigravity --model gemini-3.6-flash-high # explicit --model also works
ANTHROPIC_MODEL=gemini-3.6-flash-high crouter antigravity
```

### Unified gateway: `crouter all`

`crouter all` fuses every provider behind one fixed URL. It starts a local
Anthropic-protocol gateway (a single `ANTHROPIC_BASE_URL`) and launches Claude
Code against it. The model name carries a `<provider>/` prefix, so you switch
backends live from inside Claude Code:

```sh
crouter all                           # start the unified gateway + Claude Code
/model ollama/qwen3.5:2b              # inside Claude Code: switch to Ollama
/model deepseek/deepseek-v4-flash     # or to DeepSeek / MiniMax / Antigravity…
```

- `GET /v1/models` on the gateway returns the combined, namespaced catalog, so
  `/model` can list and switch across providers. For Ollama the catalog is
  enriched from `ollama list`, so locally-pulled models appear in `/model`.
- Each request is routed by prefix to the right backend with that backend's own
  auth (Keychain keys for MiniMax/DeepSeek, the static token for Antigravity,
  the dummy token for Ollama). Every route holds an ordered list of *candidates*
  and fails over to the next one on **401/429**, per request: keypool providers
  list one candidate per key, dual-source providers list the default account
  first and the API key second.
- The gateway listens on `127.0.0.1:${CROUTER_GATEWAY_PORT:-18799}` by default;
  override with `CROUTER_GATEWAY_PORT`. It is reaped automatically when Claude
  Code exits.
- The individual per-provider commands (`crouter ollama`, `crouter deepseek`,
  …) are untouched and still launch directly.

> Note: Claude Code's `/model` listing for a custom base URL depends on the
> Claude Code version; even if the list does not auto-populate, typing the
> namespaced model (e.g. `/model ollama/qwen3.5:2b`) works.

> **Verified (2026-08-02):** real `crouter all` traffic to `ollama/qwen3.5:2b`
> and `deepseek/deepseek-v4-flash` (keypool) both returned HTTP 200.

## How it works

The entry point:

1. Resolves its own location through symlinks, so no absolute path is hardcoded anywhere.
2. Sources `config.sh` (local, gitignored), then the selected `providers/<name>.sh`.
3. Runs the provider's optional `PRE_START` hook (for Antigravity this auto-starts the local gateway and waits for `/health`).
4. Resolves the credential according to `AUTH_MODE` — the secret exists only in the launcher process.
5. Launches Claude Code with `env -i` and a minimal, terminal-safe environment (`HOME`, `PATH`, locale, terminal capabilities), so stray shell variables such as `NO_COLOR` cannot leak in.
6. Injects endpoint, default model, model aliases (opus/sonnet/haiku/subagent), context window, reasoning effort (`--effort`, from the provider `EFFORT` field), and any provider `EXTRA_ENV`.

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
EFFORT=""                                   # reasoning effort: low|medium|high|xhigh|max (-> claude --effort)
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

## Dual-source providers: default account first, API key as fallback

`anthropic`, `openai` and `openrouter` do not use `AUTH_MODE`. They declare up to
two *credential surfaces* and crouter always spends the **default account's
included quota first**, falling back to the metered API key on **401/429**:

```sh
# --- preferred "default account" (tried FIRST) ---
DEFAULT_URL="https://api.anthropic.com"
DEFAULT_AUTH_TYPE="bearer"                  # sent as Authorization: Bearer
DEFAULT_TOKEN_ENV="CLAUDE_CODE_OAUTH_TOKEN"
DEFAULT_TOKEN_ENV_FALLBACK="ANTHROPIC_AUTH_TOKEN"   # optional second env name

# --- fallback API surface ---
API_URL="https://api.anthropic.com"
API_AUTH_TYPE="x-api-key"                   # sent as x-api-key
API_KEY_ENV="ANTHROPIC_API_KEY"
API_KEY_REF="anthropic-api-key"             # optional macOS Keychain service
```

The two surfaces may use **different URLs and different header shapes**. This
matters: an Anthropic subscription OAuth token is only valid as
`Authorization: Bearer` — sending it as `x-api-key` gets it rejected. crouter
never sends both headers for a dual-source provider.

Rotation is real, not just a start-up choice:

* **`crouter <provider>`** — when both surfaces are configured, crouter fronts
  them with `bin/keypool-proxy` (candidate mode) and points Claude Code at it,
  so a 401/429 rotates to the API key **mid-session**. With only one surface
  configured it connects directly, with no proxy overhead.
* **`crouter all`** — each surface becomes a candidate on that provider's route
  and the unified gateway fails over per request.

`crouter list` shows `dual` (both surfaces declared) or `apikey` (single
surface); `crouter doctor` reports which credentials are actually live, e.g.
`auth:ok(default+api)`.

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
# PLUS_URL="https://.../anthropic"
# PLUS_KEYS="minimax-coding-1 minimax-coding-2"
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

## Manage keys from the command line

The gateway ships three subcommands that mutate a keypool provider's
`AUTH_KEYS` / `PLUS_KEYS` list and the corresponding macOS Keychain
entries, so you never need to hand-edit `providers/<name>.sh` or paste
keys on the command line (where they'd land in shell history).

```sh
crouter add <provider>                       # add a key (auto-named)
crouter add <provider> --name my-key-3       # add with explicit Keychain service name
crouter add <provider> --surface plus      # add to the PLUS_KEYS surface instead
crouter remove <provider> --name my-key-2    # remove from the keypool (asks for confirmation)
crouter remove <provider> --name my-key-2 -y # skip confirmation
crouter list keys <provider>                 # show what's registered, plus Keychain presence
```

`add` reads the secret from `/dev/tty` with no echo, so the key never
appears in `argv` or your shell history. `rotate` requires the name to
already be listed (use `add` to register a new key). `list keys` prints
both surfaces of a keypool provider, or a single-key summary for any
other `AUTH_MODE`. The provider must be in `AUTH_MODE="keypool"` for
`add` / `rotate` / `remove`; the gateway refuses otherwise.

## Providers

### Anthropic Claude

Endpoint `https://api.anthropic.com`, default `claude-sonnet-4`, 200k context.
This is a [dual-source provider](#dual-source-providers-default-account-first-api-key-as-fallback):
your **Claude subscription (Pro/Max) OAuth token is spent first**, and the
metered Console API key only takes over on 401/429.

```sh
# 1) Default account — subscription quota (preferred).
#    `claude setup-token` mints a long-lived OAuth token for your logged-in plan.
export CLAUDE_CODE_OAUTH_TOKEN="$(claude setup-token)"   # or reuse ANTHROPIC_AUTH_TOKEN

# 2) Fallback — Console API key, billed per token. Keychain keeps it out of your rc file.
read -s "ANTHROPIC_KEY?Paste Anthropic API key: "; echo
security add-generic-password -U -a "$USER" -s "anthropic-api-key" -w "$ANTHROPIC_KEY"
unset ANTHROPIC_KEY

crouter doctor anthropic     # -> anthropic  auth:ok(default+api)
crouter anthropic
```

| Claude Code selection | Model |
| --- | --- |
| Default, `/model sonnet`, subagents | `claude-sonnet-4` |
| `/model opus` | `claude-opus-4-5` |
| `/model haiku` | `claude-haiku-4` |

Configure only one of the two and crouter connects directly to it — the failover
proxy is only started when both are present.

### OpenAI GPT

Endpoint `https://api.openai.com/v1/messages` (OpenAI's Anthropic-compatible
Messages API), default `gpt-4o`, 128k context. Also dual-source, but the
"default account" here is an **optional** gateway you point at yourself — e.g. an
org proxy or a pooled-quota endpoint. Leave it unset to go straight to the key.

```sh
# Fallback (usually all you need):
read -s "OPENAI_KEY?Paste OpenAI API key: "; echo
security add-generic-password -U -a "$USER" -s "openai-api-key" -w "$OPENAI_KEY"
unset OPENAI_KEY

# Optional preferred surface, spent before the metered key:
export OPENAI_DEFAULT_URL="https://my-org-gateway.example.com/v1/messages"
export OPENAI_DEFAULT_TOKEN="..."

crouter openai
```

Verify your key actually has access to the Messages API before relying on it —
`/v1/messages` is newer than the classic `/v1/chat/completions` surface.

### OpenRouter

Endpoint `https://openrouter.ai/api/v1`, default `anthropic/claude-sonnet-4`.
Single auth surface (Bearer), so `crouter list` shows `apikey`, not `dual`.

```sh
read -s "OPENROUTER_KEY?Paste OpenRouter API key: "; echo
security add-generic-password -U -a "$USER" -s "openrouter-api-key" -w "$OPENROUTER_KEY"
unset OPENROUTER_KEY

crouter openrouter
```

The provider sets `ANTHROPIC_API_KEY=` (empty) in `EXTRA_ENV`, as OpenRouter's
Claude Code integration guide requires — a leftover Anthropic key otherwise
conflicts with the OpenRouter token. Model IDs keep their vendor prefix, so under
`crouter all` they read `openrouter/anthropic/claude-sonnet-4` (the gateway only
strips the first path segment).

### MiniMax Token Plan

China endpoint `https://api.minimaxi.com/anthropic`, default `MiniMax-M3`, 1,048,576-token input context. It runs in `AUTH_MODE="keypool"`: the Keychain item `codex-minimax-token-plan` is the first entry in `AUTH_KEYS`, and you can add more keys, or a separate Coding Plan surface via `PLUS_URL`/`PLUS_KEYS` — see [Key pool & automatic failover](#key-pool--automatic-failover). To set or rotate a key without shell-history exposure:

```sh
read -s "MINIMAX_TOKEN_PLAN_KEY?Paste MiniMax Token Plan Key: "
echo
security add-generic-password -U -a "$USER" -s "codex-minimax-token-plan" -w "$MINIMAX_TOKEN_PLAN_KEY"
unset MINIMAX_TOKEN_PLAN_KEY
```

#### MiniMax MCP tools (auto-wired)

Launching `crouter minimax` automatically wires up MiniMax's MCP servers and the
multimodal skill **when a Token Plan key (`codex-minimax-token-plan` in Keychain)
is present** — no manual `claude mcp add` needed:

- `minimax-coding` (`MiniMax-Coding-Plan-MCP`): `web_search` + `understand_image`
- `minimax-gen` (`MiniMax-MCP`): `text_to_image` / `generate_video` / `music_generation`
  / `voice_clone` / `voice_design` …
- `minimax-multimodal-toolkit` skill (official `MiniMax-AI/skills`, backed by `mmx-cli`)

The wiring uses the official `uvx` install method (pinned to `mcp==1.9.4`, because
MiniMax's packages import the removed `mcp.server.fastmcp` path under mcp 2.x) and
is idempotent — already-registered servers and installed skills are skipped. The
tools share the `coding_plan` quota with the model endpoint, so a working Token
Plan key is required.

**Turn it off.** Copy `config.example.sh` to `config.sh` and set:

```sh
MINIMAX_AUTO_MCP=0   # disable both MCP servers + the skill
# or keep the MCP servers but skip the skill clone:
MINIMAX_AUTO_SKILL=0
```

`claude mcp list` should then show `minimax-coding … ✔ Connected` and
`minimax-gen … ✔ Connected`.

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

Launching either Antigravity provider auto-starts the gateway if it is not running (`PRE_START` hook waits for `/health`).

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

### Ollama (local / cloud open-weight models)

Ollama v0.14.0+ exposes the Anthropic Messages API natively on `http://localhost:11434`, so Claude Code talks to it with **no translation proxy and no API key** — only a dummy `ANTHROPIC_AUTH_TOKEN` (Ollama ignores its value). `providers/ollama.sh` sets `AUTH_MODE="none"` and injects `ANTHROPIC_AUTH_TOKEN=ollama` via `EXTRA_ENV`; `PRE_START` verifies the Ollama service is up and `HEALTH_CHECK_URL` lets `doctor` check it.

One-time setup:

```sh
ollama pull glm-4.7-flash            # default; qwen3.5:2b verified locally; or qwen3-coder / gpt-oss:20b / a :cloud model
```

Launch (override the model per session — Claude Code requests opus/sonnet/haiku tiers internally):

```sh
crouter ollama --model glm-4.7-flash
```

To make the default tier aliases "just work", alias a local model to a tier name:

```sh
ollama cp glm-4.7-flash claude-3-5-sonnet
```

| Claude Code selection | Ollama model |
| --- | --- |
| Default / opus / sonnet / haiku / subagents | `glm-4.7-flash` (the `MODEL_*` defaults in `providers/ollama.sh`) |

Note: Ollama defaults a model's context window small; agentic Claude Code needs a large one. The provider sets `CLAUDE_CODE_MAX_CONTEXT_TOKENS=65536` as a safe floor — raise it per your VRAM (bake `num_ctx` into a Modelfile, or set `OLLAMA_CONTEXT_LENGTH` before `ollama serve`). Optional `EFFORT` (e.g. `medium`) is available for thinking-capable models; leave it empty otherwise.

> **Verified (2026-08-02):** started `ollama serve` and ran `crouter ollama --model qwen3.5:2b -p "Reply with exactly one word: pong"` end-to-end — Claude Code connected via the injected `ANTHROPIC_BASE_URL=http://localhost:11434` + `ANTHROPIC_AUTH_TOKEN=ollama` and returned `pong`. No proxy, no API key.

## What to commit

| Content | Commit? |
| --- | --- |
| Launcher framework, provider examples, README | Yes |
| `config.example.sh` | Yes |
| Your real `config.sh` | No (gitignored) |
| Keychain item names, env var names | OK |
| API keys, Google account data, logs, account files | Never |

## Troubleshooting

- `crouter doctor` checks the Claude binary, config, curl/keychain availability, per-provider auth, and gateway health.
- Antigravity gateway logs: `logs/antigravity-proxy.log`.
- MiniMax 401: confirm the Keychain item holds a China Token Plan key.
- If an Antigravity Claude model is quota-limited, use `antigravity` until it resets.

## Version & autocompletion

- Version is tracked in the `VERSION` file. `crouter --version` prints it.
- Shell autocompletion: source `completions/crouter.bash` (bash) or `completions/crouter.zsh` (zsh) from your shell rc.

## Development

- `sh test/smoke.sh` runs a minimal offline smoke test (no keychain or network required).
- On push/PR, GitHub Actions runs `shellcheck` on all scripts and the smoke test.
