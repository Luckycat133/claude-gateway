# 任务文档：ChatGPT/Codex 订阅额度反代接入 crouter（`codex` provider；原 `chatgpt` 变体已取消）

> 状态：**已定稿 + 已实现（providers/codex.sh 随 crouter 0.4.13 落地、0.4.14 修正；免 CCR，icebear0828/codex-proxy 单进程 @ :8080）**。**剩余唯一阻塞 = 真跑验证**：需用户装 icebear 单进程（Docker/.dmg）+ 完成一次 ChatGPT OAuth PKCE 登录，再用 `crouter codex` 跑通 tool_use/流式全链路。候选仓库 star/日期/兼容性已实拉；/code-review max 12 条修正已并入（见文末「代码审核修正记录」）。

## 目标
在 crouter 新增 `codex` provider，把 ChatGPT Plus / Codex 订阅额度反代进 Claude Code，使 `crouter codex` 用订阅额度跑 CC（含 tool_use / 多模态）。

## 架构死结（已确认，不依赖联网）
- Claude Code 只说 **Anthropic `/v1/messages`** 协议。
- ChatGPT 订阅反代（aurora / codex-proxy / gpt2api）吐的是 **OpenAI `/v1/chat/completions` 或 Responses API**。
- 二者不可直接互通 → **必须有一个 Anthropic↔OpenAI 翻译层**：
  - `tool_use` ↔ `tool_calls`（最难点）
  - SSE 流式事件映射（`message_start`/`content_block_delta` ↔ `delta`）
  - 多模态 content block 互转（`image_url` ↔ `image`）
- crouter 现有 `bin/gateway` 只做 candidates/failover，**没有翻译能力**，不能直接接 chatgpt。

## 候选仓库实测（2026-08-03 `gh api` + `curl` 实测）
- **`musistudio/claude-code-router`（CCR）**：**36,354⭐**，pushed **2026-08-03**（极活跃）。现已是本地网关+控制面（桌面 app / npm CLI / Docker）。npm CLI（Node 22+）无 Electron 启动，**网关默认监听 `http://127.0.0.1:3456`**（Anthropic Messages 协议），管理 UI `:3458`。支持 **custom compatible provider** → 可把 base_url 指向任意反代。CC 把 `ANTHROPIC_BASE_URL` 指向它即可。**翻译层首选。**
- **`aurora-develop/aurora`**：**2,436⭐**，pushed **2026-08-03**（活跃）。Go 二进制 / Docker。把 ChatGPT Web 后端转 OpenAI 兼容 `/v1/chat/completions`（+`/v1/responses`）。鉴权用 ChatGPT `access_token`（`eyJ...`，可放 `access_tokens.txt` 或请求头 `Authorization: Bearer`）。每 10 分钟自动续期 session/refresh token。⚠️ **tool calling 是 `<tool_call>` 文本协议模拟**（非原生），经 CCR 翻译后 CC 的 agentic 能力可能打折。订阅反代里最火。
- **`cheer932041235/api-proxy-server`（codex-proxy）**：仅 **19⭐**，pushed **2026-05-23**（3 个月停滞）→ **放弃**。
- **`new-api/new-api`**：`gh api` 返回 404（路径不存在/已更名）→ 跳过。

## 最终方案（2026-08-04 用户决策：去 CCR，crouter 不嵌套别人的 router）

> crouter 自己就是 router（顶层 gateway 做 candidates/failover），**不能再套一个 router 中间件（CCR / 9router）**。翻译层交给被路由的 provider 后端自带。

```
crouter codex provider:
  CC → codex provider BASE_URL（直接启动 crouter codex 直连 :8080，不经 gateway；候选/failover 的 bin/gateway 仅在 crouter all 模式介入）
    → icebear0828/codex-proxy (:8080, 自带 Anthropic↔Codex 翻译 + 暴露 /v1/messages)
      → ChatGPT Codex（OAuth PKCE 订阅额度, 原生 tool_use）
```
理由：icebear0828/codex-proxy 单进程即翻译层+订阅反代+ /v1/messages，crouter 只把它当一个 provider 后端路由过去；**不引入 CCR/9router 这种"router 套 router"**；tool_use 原生（aurora 文本模拟硬伤也一并规避）。

## 实施 TODO
- [x] 实测候选 star / 日期 / 兼容性（已完成）
- [x] 代码审核 icebear0828/codex-proxy 源码（原生 tool_use + 自带翻译层，已落盘结论）
- [x] 用户决策去 CCR（crouter 不嵌套别人的 router）
- [x] ChatGPT/Codex OAuth token 由 icebear 侧 OAuth PKCE 浏览器登录持有（已改：原 keychain 方案作废——AUTH_MODE=none 下 crouter 无任何 keychain 读取路径）
- [ ] 装 Docker Desktop（或接受 icebear 桌面 .dmg 常驻）
- [ ] `docker compose up -d` 拉起 icebear0828/codex-proxy（监听 :8080，OAuth PKCE 登录 ChatGPT）
- [ ] crouter `providers/codex.sh`：
  - `BASE_URL=http://127.0.0.1:8080`（icebear0828/codex-proxy，自带翻译层）
  - `AUTH_MODE=none`：上游 icebear 鉴权由其 OAuth PKCE 承担，crouter 侧不持任何凭据（「dummy/任意」非合法枚举，启动即 die，见 lib/auth.sh:44-46）
  - `EXTRA_ENV`：按 ollama 家法（providers/ollama.sh:33-38）注入非空 dummy 凭据——Claude Code 要求非空，而 AUTH_MODE=none 下 AUTH_TOKEN 为空、lib/launch.sh 不会注入 ANTHROPIC_AUTH_TOKEN/ANTHROPIC_API_KEY（除非 KEYPOOL_URL 非空）；格式为跨两行的双引号字符串（`ANTHROPIC_AUTH_TOKEN=pwd` 与 `ANTHROPIC_API_KEY=pwd` 之间是真实换行，照抄 providers/ollama.sh:37-38；占位值取 `pwd` 以匹配 icebear 自动生成的 proxy_api_key，见下条）——lib/launch.sh 按 IFS=换行逐对注入 env -i，不能写成字面 `\n` 转义（会变成非法环境变量名导致 env -i 失败）
  - ⚠️ icebear **首次启动自动生成** `data/local.yaml` 并写入 `proxy_api_key: pwd`（config-loader.ts:150-152；api-key-auth.ts:40-42 未配时直通、配了则 401）→ 方案定为：EXTRA_ENV 占位值直接用 `pwd`（与自动生成一致）；或把 local.yaml 的 `proxy_api_key` 置 `null` 后任意占位。二者皆可，**不能再说「保持未配置」**
  - `PRE_START`：端口探测 :8080，缺失则拉起 icebear（长驻进程，需用户本机 launchd 保活）。仅直接启动（`crouter chatgpt`）执行；`crouter all` 模式不跑 PRE_START（cmd_all 不调用 run_pre_start），该模式下需 icebear 常驻（launchd 保活），缺口记为已知限制
  - 模型映射（已核实 icebear dev 4db59c4 源码）：**无内置 `claude-*` → gpt 映射**（`config/models.yaml` 与 `config/default.yaml` 的 `aliases` 均空；`model.default` 运行时取 `config/default.yaml:12` 的 `gpt-5.4`，schema 兜底（config-schema.ts:82）为 `gpt-5.6-sol`——gpt-5.4 恰是 README 默认模型（gpt-5.6-sol 才不在目录内），但切勿依赖默认，必须显式传 gpt-* id；未知模型名经 model-store.ts:257-263 静默回落该默认；另：仅当配置 anthropic 上游时 claude-* 会被 upstream-router.ts:116-118 路由走，订阅场景无此行为）——旧写法「经 icebear 虚拟模型」不存在，照抄会让 CC 所有 tier 全塌成 `gpt-5.4`。正确做法：`MODEL`/`MODEL_OPUS`/`MODEL_SONNET`/`MODEL_HAIKU`/`MODEL_SUBAGENT` 直接填 icebear 真实模型 id，crouter 经 launch.sh:48-52 注入 `ANTHROPIC_MODEL`/`ANTHROPIC_DEFAULT_OPUS/SONNET/HAIKU_MODEL`/`CLAUDE_CODE_SUBAGENT_MODEL` 环境变量钉死模型，请求里根本不会出现 `claude-*` 名，无需任何虚拟模型。icebear README 模型目录：`gpt-5.5`/`gpt-5.4`（默认）/`gpt-5.4-mini`/`gpt-5.3-codex`/`gpt-5.2`/`gpt-5-codex`/`gpt-5-codex-mini`，id 后可选 `-fast`/`-high`/`-low` 后缀（可组合，如 `gpt-5.4-high-fast`）；**`gpt-5.4-codex` 不在目录**，请求会静默回落默认。**provider 不钉死档位（2026-08-04 用户要求）**：`MODEL` 只给目录内稳妥默认 `gpt-5.6-terra`；`MODEL_OPUS/SONNET/HAIKU/SUBAGENT` 一律不设（lib/provider.sh:37-40 回落 `MODEL`——默认是均衡档，无「子代理跑旗舰」浪费风险；若用户改 `MODEL` 为旗舰档则四档跟随，属预期）。**运行时目录不止上述几款**（5.6 系列 + 5.5/5.4/5.4-mini + 5.3-codex-spark + `-high/-low/-fast` 后缀变体等），一律以 `GET /v1/models/catalog` 为准。覆盖路径：`crouter codex <model>`、会话内 `/model`、或 `ANTHROPIC_DEFAULT_*_MODEL` 环境变量。
    EFFORT 处理：icebear 不靠模型名后缀，而是把 Anthropic 请求里的 `thinking.budget_tokens` 经 `budgetToEffort` 映射成 Codex `reasoning.effort`（<2000→low、<8000→medium、<20000→high、≥20000→xhigh；优先级 thinking > 模型名后缀 > `default_reasoning_effort`，默认 null 走后端默认）。crouter 的 `EFFORT` 经 launch.sh `--effort` 传给 CC、CC 转成 thinking budget，会被 icebear 自动翻译——**无需映射到 `-high/-low` 后缀**，`EFFORT` 留空走后端默认（不钉死）；需要固定档位在 config.sh 设 `EFFORT=high` 等；注意 `gpt-5-codex`/`gpt-5-codex-mini` 不支持 xhigh。
    ⚠️ lib/provider.sh:37-40 不设别名时四档全部默认成 `MODEL`：本方案默认档是均衡的 `gpt-5.6-terra`，回落无浪费风险；若把 `MODEL` 换成旗舰档则子代理会跟随（预期）。会话内 `/model` 切到 `claude-*` 名仍会回落默认，切模型请用 catalog 内真实 id。
- [ ] `config.example.sh` 加 `CHATGPT_AUTO_*`（参考 minimax 的 `MINIMAX_AUTO_MCP`；config.sh 被 .gitignore 忽略，改动须落在 install.sh 会复制的 config.example.sh 才进仓库）
- [ ] README + CHANGELOG + VERSION bump（0.4.12）
- [ ] 验证：mock + 真实 token 跑通 chat / tool_use

## 风险（更新）
- **aurora tool_calling 模拟 → CC agentic 能力可能打折**（最大不确定项）
- ChatGPT token 有封号 / 限流风险，不如官方 API 稳
- 依赖：仅 icebear0828/codex-proxy 一个长驻进程（Docker 或 dmg），沙箱不保活，需用户本机常驻
- 订阅续期依赖 aurora 维护，OpenAI 改版可能打断

## 当前阻塞
- 调研已完成。实现阻塞于：① 用户需在 icebear 内完成一次 OAuth PKCE 浏览器登录（token 由 icebear 侧持有，crouter 无需 keychain）；② 需用户批准安装 icebear0828/codex-proxy 单进程（Docker 或 dmg）。确认后我写 `codex.sh` 并接 `PRE_START`。

## 候选补充（2026-08-04 复核，user: 找一个别人常用的把 codex 额度接入 claude code 的仓库）
- **WebSearch 误导纠正**：搜到的 "VictorMinemu/CC-Router — 36k⭐ 一体化把 Codex 接入 Claude Code" 是幻觉/张冠李戴。`VictorMinemu/CC-Router` 实测仅 **23⭐、pushed 2026-06-05（停滞 2 月）**；`Timo972/cc-router` 是 **0⭐ fork**。真正 36k⭐、2026-08-04 当天还在更新的就是原定的 `musistudio/claude-code-router`（CCR，36,385⭐）。不要被 AI 摘要骗去用 VictorMinemu 那个停滞小项目。
- **新增一体化候选 `decolua/9router`（9router）：24,594⭐，pushed 2026-08-04（极活跃）**。Universal AI Proxy，开箱即用把 **OpenAI Codex (Plus/Pro) 订阅 OAuth** 接给 Claude Code / Codex / Cursor（provider 前缀 `cx/`，OAuth 登录端口 1455），另支持 40+ 免费/付费 provider + 自动 fallback。比 CCR+aurora 拼凑更对口、更省心：**无需自研翻译层 + 没有 aurora `<tool_call>` 文本模拟导致的 agentic 打折问题**（9router 的 Codex 订阅走原生 Responses/tool use）。
- **对 crouter `chatgpt.sh` 的影响（待用户拍板后端）**：
  - (A) 维持原定 **CCR + aurora**（双进程）：aurora tool_calling 文本模拟 → CC agentic 打折（已知短板）。
  - (B) 改用 **9router 单进程一体化**：`cx/` 订阅额度经 Anthropic 协议直供 Claude Code，tool use 原生，最省事且能力最全 → **倾向 (B)**。
  - 两者都需常驻进程（沙箱不保活，用户本机 launchd）+ ChatGPT/Codex OAuth token。
- 结论：用户要的"别人常用的现成仓库"≈ **9router（一体化，24.6k⭐）**；但按 2026-08-04 最终决策 **CCR 已弃用**（crouter 不嵌套别人的 router，与 :25/:86 一致），后端唯一候选是 **icebear0828/codex-proxy 单进程（自带翻译层，原生 tool_use）**，9router 仅作一体化兜底。

## 单独 codex 反代候选（2026-08-04 二次复核, user: 找一家单独的 codex）
- 用户要的是**只做 Codex/ChatGPT 订阅反代**那一层（对应 aurora 位），排除 9router/CCR 一体化。
- **`Securiteru/codex-openai-proxy`：142⭐，Rust，updated 2026-08-02（活跃）**。描述原文: 'Proxy server to use ChatGPT Plus tokens with CLINE/Claude Code extensions via OpenAI API compatibility'。**最对口'单独 codex 反代给 Claude Code 用'且活跃**，比 aurora 更专注面向 CC。
- `aurora-develop/aurora`：2.4k⭐（订阅反代里最火、通用），但 **tool_calling 是 `<tool_call>` 文本模拟 → CC agentic 打折**（TASKS 已标最大短板）。仍是'最常用'选项，但能力有损。
- 放弃: `Kitjesen/chatgpt-to-api`（5⭐，pushed 2026-02 停滞）、`gaivrt/CHATGPT-PROXY`（0⭐ 停滞）、`cheer932041235/api-proxy-server`（19⭐，偏 VPS 全家桶）。
- **建议（已过时，见代码审核结论 + 用户去 CCR 决策）**：当时想把 aurora 换成 Securiteru 做"单独 codex 反代"，翻译层想借 CCR(:3456)。**用户已决策去 CCR**，最终方案是 icebear0828/codex-proxy 单进程（自带翻译层，免 CCR）。本段保留作调研过程。

## 代码审核结论（2026-08-04，user: 你下载下来审核一下 → 已 git clone dev 分支 4db59c4 实读源码）

- **审核方式**：Bash 恢复后 `git clone --depth 1 --branch dev` 拉到本地 `/tmp/codex-proxy-review`，直接读 `src/` 源码（不是只看 README）。结论基于实读，非 AI 摘要。
- **仓库实况**：TypeScript（Hono），`src/` 120+ .ts 模块，目录分层清晰：`routes/`(messages/chat/responses/gemini/embeddings…)、`translation/`(13 个文件双向转换)、`auth/`(OAuth PKCE / 账号池 / 续期 / 轮换)、`proxy/`(cookie-jar/proxy-pool/upstream-router)、`tls/`(native addon)、`services/`、`models/`。7 个 GitHub Actions（ci-docker/ci-quality/docker-publish/release/electron×2/promote-dev-to-master），有 Dockerfile + docker-compose.yml，`find /tmp/codex-proxy-review -name '*.test.ts' | wc -l` 实测 **282 个 `.test.ts`**。**生产级工程，非玩具**。
- **核心确认 —— 这是真·原生 tool_use，不是 aurora 的 `<tool_call>` 文本模拟**：
  - `src/routes/messages.ts`：`POST /v1/messages`（Zod `AnthropicMessagesRequestSchema` 校验）→ `translateAnthropicToCodexRequest` → Codex **WebSocket 流式**（`codexRequest.useWebSocket=true`）；另含 `/v1/messages/count_tokens`（启发式估算，非真 tokenizer）、401/400/429/529 错误处理。Claude Code 把 `ANTHROPIC_BASE_URL` 指它即可。
  - `src/translation/anthropic-to-codex.ts`：`tool_use` 块 → Codex 原生 `function_call`（参数 `JSON.stringify(block.input)`）；`tool_result` → `function_call_output`。无文本伪调用。
  - `src/translation/codex-to-anthropic.ts`：`functionCallStart` → 开 `tool_use` content block；`functionCallDelta` → `input_json_delta`（**流式 partial JSON，CC 原生格式**）；`functionCallDone` → 闭合块带完整 `input`；`reasoning_delta` → `thinking_delta`。CC 看到的是真 tool_use 流，agentic 能力**不打折**。
- **认证/模型/部署（README 复核一致）**：OAuth PKCE 一键浏览器登录 + Bearer API Key + token/refreshToken 导入；多账号智能轮换、JWT 到期自动续期；模型 gpt-5.5/5.4/5.3-codex/5-codex 等（GPT-5.x 系列，后缀 `-fast/-high/-low` 切推理等级）；部署三选一 —— 桌面 .dmg（mac 推荐新手）、Docker（`docker compose up -d`，最省事、免 Rust 工具链）、源码 `npm run build && node dist/index.js`（需 Rust 编 TLS addon）。
- **对 crouter `chatgpt.sh` 的影响（重大简化）**：
  - **单进程替代 CCR + aurora 双进程（用户已决策去 CCR）**：icebear0828/codex-proxy 自带 Anthropic↔Codex 双向转换且暴露 `/v1/messages`，crouter 只需 `PRE_START` 拉起它一个进程，把 `chatgpt.sh` 的 `BASE_URL` 指向它即可，**已确定删掉 CCR 依赖（crouter 不嵌套别人的 router）**。对比原方案：省一个常驻进程、tool_use 原生（aurora 文本模拟硬伤消失）、订阅额度走 OAuth PKCE 直连 ChatGPT。
  - 部署建议：沙箱/用户本机用 **Docker（`docker compose up -d`，监听 :8080）** 最稳；hono 服务常驻仍需用户真实 macOS 会话的 launchd（沙箱不保活）。
- **后端优先级更新（截至 2026-08-04）**：
  1. **icebear0828/codex-proxy**（1.6k⭐，最后代码提交 2026-07-30，原生 tool_use + 自带翻译层 + /v1/messages）→ crouter `codex.sh` 单进程首选，**已确定免 CCR（用户决策）**。
  2. **Soju06/codex-lb**（2.6k⭐，今天更新）→ 多账号 LB + 代理 + dashboard。**但 icebear 已自带号池轮换（least_used/round_robin/sticky 三策略可配）+ 配额耗尽自动跳过 + JWT 自动续期 + 代理池 + 上游 LB + 限流/usage 统计**（2026-08-04 16:16 实读 `src/auth`+`src/proxy` 确认），单进程即覆盖，codex-lb 通常不必叠；仅当需要独立 dashboard / 多服务编排时才作上层。
  3. **aurora**（2.4k⭐，最火通用反代）→ **降级**：tool_calling 文本模拟硬伤，仅在上面都不行时兜底。
  4. **Securiteru/codex-openai-proxy**（142⭐，Rust）→ 不优选，但作为"单独 codex 反代给 CC"的轻量参考仍可看。
  - *一体化备选*：`9router`（24.6k⭐）仍可作大杂烩兜底，但 **CCR 已弃用**（router 套 router，与 crouter 定位冲突）；icebear 单进程已覆盖翻译层，优先级最高。
- **剩余风险 / 待真跑验证**：① GPT-5.x 经 Codex Responses API 回 CC 的 `tool_use` 全链路（含多工具并发、thinking 块共存）需用户给 ChatGPT/Codex OAuth token 后真跑一次确认；② Docker 镜像是否走 `ghcr.io/icebear0828/codex-proxy`（docker-compose 里确认）；③ 用户 Mac 需装 Docker Desktop 或接受 .dmg 桌面常驻。
- **当前阻塞不变**：等用户给 ChatGPT/Codex token + 批准安装（Docker 或 dmg），我就写 `codex.sh` 接 `PRE_START` 拉起 icebear0828/codex-proxy 单进程，真跑验证。

## 代码审核修正记录（2026-08-04，/code-review max 12 条 finding 全部核实并修正）
- 1 AUTH_MODE "dummy" 非法 → 定死 `AUTH_MODE=none`（lib/auth.sh 枚举）
- 2 缺 dummy 凭据 → 按 ollama 家法补 `EXTRA_ENV` 注入非空占位（Claude Code 要求非空）
- 3 "claude-* 虚拟模型映射" 不存在 → MODEL_* 别名直接填 icebear 真实 gpt-* id
- 4 "gpt-5.4-codex" 非真实 id（静默回落默认）→ 改用目录内 id
- 5 icebear `proxy_api_key` 会导致 401 → 要求保持未配置（复审后修正：首次启动自动生成 pwd，见 13）
- 6 keychain 存 token 死重 → 改为 icebear OAuth PKCE 登录持有
- 7 PRE_START 在 `crouter all` 不执行 → 已标注缺口
- 8 架构图 gateway/failover 仅 all 模式成立 → 已修正图示
- 9 漏 MODEL_OPUS/SONNET/HAIKU/SUBAGENT + EFFORT → 已补
- 10 config.sh gitignored → 改 config.example.sh
- 11 状态行过期 + CCR 矛盾 → 已同步 08-04 最终决策
- 12 "2 个 .test.ts" → 实读 282 个
- 13 proxy_api_key 首次启动自动生成 `pwd`（config-loader.ts:150-152）→ 占位用 pwd 或置 null，非「保持未配置」
- 14 「两值都不在 README 目录」错：gpt-5.4 恰是 README 默认模型
- 15 icebear「今天更新」→ 最后代码提交 2026-07-30
- 16 count_tokens 为启发式估算（非真 tokenizer）
- 17 行号修正：api-key-auth 36-40→40-42；budgetToEffort 70-75→70-76
- 18 9router：pushed 07-30 非 08-04；非单二进制（Next.js 应用）；README 列 gpt-5.3-codex/5.2-codex 已不在目录
- 19 Securiteru「活跃/面向 CC」失实：2025-08 后零提交、面向 CLINE、真集成是 dead code
- 20 XxxXTeam「08-02 更新」→ master 冻结 06-26（v1.9.0）；缺 count_tokens 对 CC 无实际影响
- 21 GPT-5.6 系列（2026-07-09 发布）：openai.sh 与 codex 草案模型档位更新为 gpt-5.6-sol/terra/luna（openai.sh 初版用 5.5/5.4 属落后，已改）
- 22 codex.sh 不钉死模型档位（2026-08-04 用户要求）：仅 `MODEL` 默认 gpt-5.6-terra，四档别名不设、回落 MODEL，目录以运行时 catalog 为准

## crouter codex provider（2026-08-04 定稿：8 仓库独立复审后确认与 chatgpt 共用后端）

**结论：`crouter codex` 不引入新后端** —— icebear 的 OAuth PKCE 登录对象就是 ChatGPT 账号（含 Codex 额度）。**2026-08-04 用户确认：`chatgpt` 独立 provider 变体取消，只实现 `codex.sh` 一个**（同后端、同登录、同额度），不再拆模型预设变体。

**8 仓库复审汇总**（每仓库 1 个 agent 源码级审查，报告在 /tmp/crouter-codex-research/reviews/）：

| 仓库 | ⭐ | 判定 | 一句话理由（源码证据） |
|---|---|---|---|
| icebear0828/codex-proxy | 1,644（07-30 最后提交） | ✅ 首选（chatgpt/codex 共用） | /v1/messages(:152) + count_tokens(:138)、tool_use 原生、OAuth PKCE；无 LICENSE |
| XxxXTeam/codex-proxy | 160（06-26 master 冻结） | 🥈 license 敏感备选 | GPL-3.0、Go 单二进制、全流式 SSE；`--effort` 被转换层丢弃，须编码进模型后缀 |
| james-6-23/codex2api | 1,861（今天更新） | ❌ 过重 | 69.5k 行 Go 计费级多租户网关；无 LICENSE |
| insightflo/chatgpt-codex-proxy | 42（3 月中休眠） | ❌ 减分项多 | 假流式（全量缓冲后重放）；无 LICENSE 文件；绑全部网卡 |
| aurora-develop/aurora | 2,437（08-03） | ❌ 仅兜底 | `<tool_call>` 文本模拟坐实（toolcall/parser.go:1-9 自证）+ 无 Anthropic 面 |
| Soju06/codex-lb | 2,585（今天更新） | ❌ 不可直连 | 全库无 Anthropic 协议（仅 OpenAI/Codex 原生面） |
| decolua/9router | 24,628（07-30） | ❌ 架构冲突 | 自带 router+dashboard 违背去 CCR 决策；cx/ 官方标 deprecated+RISK_NOTICE |
| Securiteru/codex-openai-proxy | 142（2025-08 后零提交） | ❌ 不可用 | 活跃路径返回硬编码占位文案，真实转发是 dead code |

**`crouter codex` 参数草案**（照 ollama.sh:25-40 家法，与 chatgpt.sh 同后端、同登录）：
- `BASE_URL="http://localhost:8080"`；仅 `MODEL="gpt-5.6-terra"` 一个默认（**不钉死档位**：四档别名不设、回落 MODEL）；`CONTEXT_TOKENS="1050000"`（1.05M ctx，0.4.14 修正：原草案 272000 少 10 倍）；完整目录以 `GET /v1/models/catalog` 为准
- `AUTH_MODE="none"` + EXTRA_ENV 占位 `pwd`（与 icebear 自动生成的 proxy_api_key 一致）；`PRE_START` 端口探测 :8080（仅直连模式生效）；`HEALTH_CHECK_URL="http://localhost:8080/health"`（0.4.14 修正：原草案指向 `/`）
- 风险：模型随账号 plan 变（free 静默降级）、无 LICENSE、封号/限流、OpenAI 改版打断逆向链路

## 真跑验证发现（2026-08-05，user: 测 codex）
- **框架层启动链路 PASS**：`crouter codex -p test`（mock claude）正常启动，env 注入正确 — `ANTHROPIC_BASE_URL=http://localhost:8080`、`ANTHROPIC_AUTH_TOKEN/API_KEY=pwd`、`ANTHROPIC_MODEL`+三档 default 均回落 `gpt-5.6-terra`。证明 codex.sh 变量契约无误。
- **真链路 BLOCKED + 根因**：`:8080` 被 **WorkBuddy 自身「媒体压缩」dashboard**（PID 8706 `dashboard_server.py --port 8080`）占用，**不是 icebear**。icebear 未安装/未启动/未 OAuth → CC 真请求会打到 media-compress 得 HTML 404。
- **端口三方冲突**：icebear 默认 8080 = codex.sh 写死 `BASE_URL=http://localhost:8080` = WorkBuddy media-compress 8080。**修复**：codex.sh 端口改非 8080（如 19000 空闲端口）+ icebear 同步改 `--port`/compose 端口；勿停 media-compress（WorkBuddy 内部服务）。
- **PRE_START 探测缺陷（真 bug）**：当前 `curl -fsS http://localhost:8080`（根 /）只查 2xx，被任意占 8080 的服务骗过 → 误判 icebear 在跑、无声启动到错误后端。应与 `HEALTH_CHECK_URL` 一致改探 `/health`（icebear 真暴露 `src/routes/admin/health.ts`）。建议：`PRE_START='curl -fsS --max-time 3 http://localhost:8080/health >/dev/null 2>&1 || die ...'`。
- 剩余真验证仍需：装 icebear（改端口后 `docker compose up -d`）+ ChatGPT OAuth 登录 + `crouter codex` 真打 tool_use。
