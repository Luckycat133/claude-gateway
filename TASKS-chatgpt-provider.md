# Codex provider decision record

> Status: implementation complete for crouter 0.5.1. A credentialed end-to-end
> request still depends on the account owner running the local proxy, completing
> ChatGPT OAuth PKCE login, and accepting any provider-side usage consequences.

## Supported architecture

```text
Claude Code
  -> crouter codex
  -> icebear0828/codex-proxy at http://localhost:19000
  -> ChatGPT/Codex subscription account
```

The local proxy owns OAuth, Anthropic-to-Codex request translation, streaming,
and tool-call conversion. crouter treats it as one Anthropic-compatible local
backend. It does not read, store, forward, or rotate the user's ChatGPT OAuth
credential, and it does not insert another general-purpose router such as CCR
or 9router.

This provider is separate from both Anthropic access paths:

- `crouter claude` transparently uses Claude Code's native stored account.
- `crouter anthropic` uses an Anthropic Console API key.
- `crouter codex` uses the locally authenticated ChatGPT subscription proxy.

## Current provider contract

`providers/codex.sh` declares:

- base URL `http://localhost:19000`;
- health endpoint `http://localhost:19000/health`;
- Opus/default `gpt-5.6-sol`, Sonnet `gpt-5.6-terra`, and
  Haiku/subagent `gpt-5.6-luna`;
- a 1,050,000-token client context setting;
- `AUTH_MODE=none`, with the local `pwd` placeholders required by Claude Code
  and the proxy's default local authentication contract;
- a `PRE_START` health gate that fails with an actionable startup/login hint.

The proxy's available catalog is account- and release-dependent. Use its live
catalog and `crouter codex <model>` when selecting a model outside the
configured tiers; do not infer entitlement from the static crouter mapping.

## Operator setup

1. Install and start `icebear0828/codex-proxy` on port 19000.
2. Complete its ChatGPT OAuth PKCE login in the user's own browser session.
3. Confirm `curl -fsS http://localhost:19000/health` succeeds.
4. Run `crouter doctor codex`, then `crouter codex`.

`crouter all` can include the Codex route only while the local proxy is already
running. Unified mode deliberately does not run provider `PRE_START` hooks.
Use `crouter all --check` for a redacted, non-networked route proof; it cannot
prove that the local service is healthy or that the account has remaining
subscription quota.

## Verification and release boundary

The repository tests verify the provider declaration, 19000 health gate,
model/context injection, local-route construction, launch cleanup, and
`crouter all --check` behavior under both POSIX `sh` and `dash`. These tests do
not possess a user's OAuth session and do not make a paid or subscription
request.

The implementation is therefore complete at the crouter boundary. Runtime
failures caused by an absent local proxy, incomplete OAuth login, account plan
limits, or a changed proxy catalog remain external operational conditions, not
credentials that crouter should attempt to capture.

## Rejected designs

- Direct OpenAI API routing was removed because OpenAI does not publish a
  directly usable Anthropic Messages base URL for Claude Code.
- CCR/9router plus another subscription bridge duplicated crouter's routing
  layer and increased failure and credential surfaces.
- Aurora-style text-emulated tool calls were rejected in favor of a proxy that
  owns native request, streaming, and tool-call translation.
- Port 8080 was abandoned after it collided with another local service; the
  provider and health check now consistently use port 19000.
