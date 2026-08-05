#!/bin/sh
# Provider: Codex via icebear0828/codex-proxy (ChatGPT/Codex 订阅额度).
# icebear 单进程自带 Anthropic↔Codex 双向翻译，暴露 /v1/messages（:8080）；
# 订阅鉴权由其 OAuth PKCE 承担，crouter 侧不持任何凭据。
#
# 模型不钉死（2026-08-04）：icebear 的模型目录是运行时从 Codex 后端拉取的
# （GET /v1/models/catalog，随账号套餐变化，含 gpt-5.6-sol/terra/luna、
# -high/-low/-fast 后缀变体等），这里只给一个目录内稳妥默认值；四档别名不设、
# 回落 MODEL（默认是均衡档，无浪费风险）。换模型：`crouter codex <model>`、
# 会话内 /model、或 ANTHROPIC_DEFAULT_*_MODEL 环境变量。
PROVIDER_NAME="codex"
PROVIDER_DESC="ChatGPT/Codex 订阅额度经 icebear0828/codex-proxy 进 Claude Code"

BASE_URL="http://localhost:19000"
MODEL="gpt-5.6-terra"           # 仅默认值；目录以 GET /v1/models/catalog 为准
CONTEXT_TOKENS="1050000"        # GPT-5.6 家族 1.05M ctx（icebear bridge.ts 印证）

# 档位别名不设：lib/provider.sh 回落 MODEL（均衡档，无浪费风险）。

# 推理 effort 不钉死：icebear 把 thinking budget 映射为 reasoning effort，
# 留空走后端默认；需要固定档位可在 config.sh 设 EFFORT=high 等。
EFFORT=""

# icebear 首次启动自动生成 data/local.yaml 的 `proxy_api_key: pwd`
# （config-loader.ts:150-152），未配则 /v1/messages 无鉴权直通。这里注入与
# 自动生成一致的占位值（Claude Code 要求非空凭据）。
AUTH_MODE="none"
EXTRA_ENV="ANTHROPIC_AUTH_TOKEN=pwd
ANTHROPIC_API_KEY=pwd"

# 端口探测：缺失则提示启动方式。仅直接启动（crouter codex）执行；
# `crouter all` 模式不跑 PRE_START，需 icebear 常驻（launchd / .dmg）。
PRE_START='curl -fsS --max-time 3 http://localhost:19000/health >/dev/null 2>&1 || die "icebear0828/codex-proxy 未在 http://localhost:19000/health 运行 — 在其仓库目录 docker compose up -d (--port 19000)，或运行 .dmg 并完成 ChatGPT 登录"'
POST_STOP=""
HEALTH_CHECK_URL="http://localhost:19000/health"
