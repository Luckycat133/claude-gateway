# Upstream PR: add gpt-oss family to `getModelFamily` / `isSupportedModel`

## Repository
- Upstream: `badrisnarayanan/antigravity-claude-proxy`
- Base branch: `main`

## Files changed
- `src/constants.js` — `getModelFamily()` returns `'gpt-oss'` for model names
  containing the substring `gpt-oss`.
- `src/cloudcode/model-api.js` — `isSupportedModel()` also accepts the
  `gpt-oss` family.

## Patch file
`0001-feat-add-gpt-oss-family-to-getModelFamily.patch` (in this directory)
contains the unified diff. Generated with:

```sh
cd antigravity-claude-proxy
git format-patch -1 HEAD --stdout > ../docs/upstream-pr/0001-feat-add-gpt-oss-family-to-getModelFamily.patch
```

## Motivation
The Antigravity UI exposes OpenAI's open-weight `GPT-OSS 120B (Medium)`
model alongside the Claude and Gemini tiers. The proxy's request
validation (`server.js` calls `isValidModel()`) rejects any model name
whose family is neither `claude` nor `gemini`:

```
Error: invalid_request_error: Invalid model: gpt-oss-120b-medium.
Use /v1/models to see available models.
```

`getModelFamily()` is the single chokepoint: it returns one of
`'claude' | 'gemini' | 'unknown'`, and `isSupportedModel()` filters on
that result. Adding a third family branch unblocks GPT-OSS without
touching request/response conversion (which is intentionally family-gated
for Claude and Gemini today; GPT-OSS uses the same Google Generative-AI
envelope for tools and thinking that the Gemini path uses, so it works
out of the box once it passes validation).

## What this PR does NOT do
- It does not add `gpt-oss-120b-medium` to `MODEL_FALLBACK_MAP`. That map
  is for quota-exhaustion fallback between known model pairs, and
  adding a new entry would require picking a fallback target without
  evidence about quota behavior. Better to land the validation change
  first, observe real usage, and add fallback entries in a follow-up.
- It does not modify request/response converters. GPT-OSS requests take
  the family-agnostic path (no Claude thinking config, no Gemini thinking
  recovery, no family-specific tool_use handling). For pure-text
  requests this is sufficient; tool-use may need a follow-up once we
  have observed what works upstream.

## How to submit (no `gh` CLI / no auth in this environment)

```sh
# 1. Fork badrisnarayanan/antigravity-claude-proxy on GitHub to your account.

# 2. Add the fork as a remote and apply the patch.
cd /path/to/your/fork
git remote add upstream https://github.com/badrisnarayanan/antigravity-claude-proxy.git
git checkout -b feat/gpt-oss-family
git am /path/to/crouter/docs/upstream-pr/0001-feat-add-gpt-oss-family-to-getModelFamily.patch

# 3. Push the branch to your fork.
git push origin feat/gpt-oss-family

# 4. Open the PR via the GitHub web UI against upstream/main, using the
#    body below.
```

## Suggested PR body (paste when opening the PR on GitHub)

> The Antigravity desktop app now exposes OpenAI's open-weight
> `GPT-OSS 120B (Medium)` model alongside the Claude and Gemini tiers.
> The proxy currently rejects these names in `isValidModel()` because
> `getModelFamily()` only recognises the `claude` / `gemini` substrings,
> so any `crouter antigravity-claude --model gpt-oss-120b-medium` (or
> direct API call to `/v1/messages`) returns
> `invalid_request_error: Invalid model: gpt-oss-120b-medium`.
>
> This adds a third family branch for any name containing `gpt-oss` and
> extends `isSupportedModel()` accordingly. Request/response conversion
> falls through the family-agnostic path, which is the same envelope
> the Gemini path uses upstream.
>
> Patch scope is intentionally minimal — no `MODEL_FALLBACK_MAP` entries
> (need observed quota behavior first) and no converter changes (need
> observed tool-use / thinking behavior first). Happy to follow up with
> either once the validation change is in production.

## Local fallback

Until the upstream PR merges, the `crouter` companion script
`bin/antigravity-proxy-patch` applies the same patch idempotently on a
local proxy checkout. It is wired into `install.sh`, so a fresh
`./install.sh` next to a fresh `git clone` of the proxy configures
GPT-OSS end-to-end without touching the upstream repo.