# Upstream PR: add gpt-oss family to `getModelFamily` / `isSupportedModel`

## Status
**Open (checked 2026-08-09)**:
https://github.com/badrisnarayanan/antigravity-claude-proxy/pull/362

## Repository
- Upstream: `badrisnarayanan/antigravity-claude-proxy`
- Fork: `Luckycat133/antigravity-claude-proxy`
- Branch: `feat/gpt-oss-family`
- Base branch: `main`

## Files changed
- `src/constants.js` — `getModelFamily()` returns `'gpt-oss'` for model names
  containing the substring `gpt-oss`.
- `src/cloudcode/model-api.js` — `isSupportedModel()` also accepts the
  `gpt-oss` family.

## Patch file
`0001-feat-add-gpt-oss-family-to-getModelFamily.patch` (in this directory)
contains the unified diff that was applied to the fork. The same diff is
what `bin/antigravity-proxy-patch` applies idempotently on local proxy
checkouts.

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

## Local fallback (no longer needed once PR #362 merges)

Until the upstream PR merges, the `crouter` companion script
`bin/antigravity-proxy-patch` applies the same patch idempotently on a
local proxy checkout. It is wired into `install.sh`, so a fresh
`./install.sh` next to a fresh `git clone` of the proxy configures
GPT-OSS end-to-end without touching the upstream repo.
