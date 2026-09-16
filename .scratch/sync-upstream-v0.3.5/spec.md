---
labels: [ready-for-agent]
---

# Spec: 同步上游 v0.3.5（含 TUI/会话存储/WebUI 大版本升级）

## Problem Statement

fork 当前 `main`（`3c37ddb2`，2026-09-16）叠加在 10 个本地提交之上（含新完成的 fork 补丁层重构），上游基线是 `588be51d`（2026-09-03）。上游已发布 **v0.3.5**（`1bb712d3`，2026-09-16），**领先 fork 166 个提交**，包含 117 个 fix、16 个 feat 以及多项破坏性变更（TUI 默认入口、会话存储路径迁移、网关生命周期语义、Email 认证信任锚、配置字段废弃）。

fork 的 5 个本地改动文件（`loop.py`、`runtime.py`、`manager.py`、`http_utils.py`、`ws_http.py`）在 v0.3.5 中均有 60~600 行不等的上游改动，直接 rebase 必然产生冲突。但 **fork 补丁层重构已把内联逻辑抽到 `nanobot/fork/` 包**（上游永不触碰），这些文件现在只保留薄调用点 + `# FORK-HOOK` 锚点——冲突面已从"整块逻辑"缩小到"14 个锚点调用点"。同时 v0.3.5 的会话存储迁移会影响 `user_session_map.py` 依赖的会话目录结构，TUI 默认入口会影响 `nanobot gateway` 启动路径，Chrome 扩展（dct-nanobot）依赖的 WS mutation 协议需要验证兼容。

不升级会持续落后上游 13 天修复（含安全修复），升级需要按锚点清单重新贴回调用点并验证扩展兼容。

## Solution

将 fork 的 10 个本地提交 rebase 到上游 `v0.3.5` 之上，**依据 `docs/fork-integration.md` 的 hook 清单逐个重新贴回 `# FORK-HOOK` 调用点**（`nanobot/fork/` 逻辑零改动），然后完成三层验证（自动化测试、运行时功能、Chrome 扩展端到端）。升级路径沿用已确立的 `git pull --rebase upstream main` 工作流（nanobot skill），先备份 `main` 指针再执行；`git rerere` 已启用，历史冲突解决方案自动复用。

## User Stories

1. As a fork maintainer, I want to rebase my 10 local commits onto upstream v0.3.5, so that the fork keeps the upstream bug fixes and new features.
2. As a fork maintainer, I want my local `user_session_map` feature (user↔session association) to survive the rebase, so that session filtering by user continues to work.
3. As a fork maintainer, I want my local CORS support (`cors_origin` parameter) to survive the rebase, so that the Chrome extension can reach the gateway cross-origin.
4. As a fork maintainer, I want my local navigation metadata channel (`<!--NAV:-->` marker → `navigation` WS event) to survive the rebase, so that the extension receives navigation directives.
5. As a fork maintainer, I want my local LLM error masking ("模型服务暂时不可用") to survive the rebase, so that users never see raw model/API error text.
6. As a fork maintainer, I want my local CLI App local-install fallback (`apps/cli/service.py`) to keep working, so that `dct-north-cli` runs even when pip strategy fails.
7. As a fork maintainer, I want the upstream v0.3.5 TUI default entry point (`nanobot` → TypeScript TUI) to not break my gateway startup command, so that the gateway still launches with the documented flags.
8. As a fork maintainer, I want the upstream v0.3.5 session storage migration (`sessions/<workspace-id>/`) to run cleanly, so that existing conversations are preserved after upgrade.
9. As a fork maintainer, I want the upstream v0.3.5 `WebUICommandRouter`-era WS protocol to remain wire-compatible with the Chrome extension, so that session delete (mutation), `new_chat` user association, and message send all keep working.
10. As a fork maintainer, I want the upstream v0.3.5 CI gates (BasedPyright strict, ruff) to pass on my rebased fork, so that the fork remains mergeable upstream.
11. As a fork maintainer, I want the rebase to be reversible, so that I can roll back to the pre-upgrade state if the upgrade is incomplete.
12. As a fork maintainer, I want a verified upgrade record (tests + runtime checks), so that I can confirm no regression was introduced by the rebase.

## Implementation Decisions

### 升级范围与基线

- **目标基线**：上游 tag `v0.3.5`（`1bb712d3`），而非 `upstream/main`（main 可能继续前进，tag 提供稳定升级点）。
- **升级方式**：`git rebase v0.3.5`（重放 10 个本地提交），不是 merge——与 nanobot skill 的 `--rebase` 工作流一致。
- **备份**：rebase 前在 `backup-main-before-v035` 分支记录当前 `main` 指针（`3c37ddb2`）。

### 冲突点（fork 补丁层重构后的实际状态）

**前提**：fork 逻辑已抽到 `nanobot/fork/`（上游零冲突）；上游文件只剩 `# FORK-HOOK` 锚点调用点。以下文件在 v0.3.5 有上游改动，rebase 时锚点可能位移/消失，需按 `docs/fork-integration.md` 清单核对：

| 文件 | v0.3.5 改动规模 | 需核对的锚点 |
|---|---|---|
| `nanobot/agent/loop.py` | 602 diff 行 | `fork-nav-stream`、`fork-err-mask`、`fork-nav-persist` |
| `nanobot/channels/websocket/runtime.py` | 536 diff 行 | `fork-nav-dispatch`（`send_projected_message`） |
| `nanobot/webui/ws_http.py` | 457 diff 行 | `fork-cors-constant`、`fork-cors-bootstrap`、`fork-user-map-filter`、`fork-user-map-dissociate` |
| `nanobot/channels/manager.py` | 213 diff 行 | `fork-nav-send`（2 处） |
| `nanobot/webui/http_utils.py` | 63 diff 行 | 无锚点（CORS 常量已移走，仅保留 `cors_origin` 签名参数） |
| `nanobot/webui/inbound_commands.py` | 上游改动 | `fork-user-map-associate` |

### 已完成的预置工作（fork 补丁层重构）

1. **`nanobot/fork/` 包**：`parse_nav_marker()`、`mask_llm_error()`、`cors.py`、`user_session.py` 全部独立，上游 rebase 零冲突。
2. **`docs/fork-integration.md`**：14 个锚点清单 + rebase 检查清单（`git grep "FORK-HOOK:"` 与文档一一对应）。
3. **`git rerere`** 已启用（`rerere.enabled true`），首次 rebase 仍需手动解决，后续自动复用。
4. **`tests/fork/` + 导航分发测试**：纯函数已单测覆盖，升级后同样作为回归基线。

### fork 特性移植规则（沿用 docs/fork-integration.md 的 hook 清单）

1. **用户会话映射**：`fork-user-map-associate`（`inbound_commands.py` `new_chat` 分支）、`fork-user-map-filter`/`fork-user-map-dissociate`（`ws_http.py`）。
2. **导航元数据**：`fork-nav-stream`/`fork-nav-persist`（`loop.py`，经 `parse_nav_marker`）、`fork-nav-send`（`manager.py`）、`fork-nav-dispatch`（`runtime.py`）。
3. **错误掩蔽**：`fork-err-mask`（`loop.py`，经 `mask_llm_error`）。
4. **CORS**：`fork-cors-constant`/`fork-cors-bootstrap`（`ws_http.py`，常量来自 `fork/cors.py`）。
5. **WebUI 前缀边界测试**：所有 fork 代码使用 `webui_session_key()`/`WEBUI_SESSION_STORAGE_PREFIX` 常量，通过 `test_websocket_application_boundary.py`。

### 环境与运行时

- conda env `nanobot-312` 执行 `pip install -e .`（补 v0.3.5 新依赖 + 新入口点）。
- 网关重启命令不变：`python3.12 -m nanobot gateway --foreground --port 18790 --workspace ... --config ...`。
- 若 v0.3.5 的 `nanobot` 命令默认进 TUI，则 fork 网关启动**必须显式走 `nanobot gateway`**（不受 TUI 默认入口影响），并验证 `--classic`/`gateway` 子命令解析正常。

### 破坏性变更应对

- **会话存储迁移**：升级后首次启动会自动迁移；验证旧会话 JSONL 出现在 `sessions/<workspace-id>/`。降级预案：`nanobot sessions restore-workspace`。
- **`/health` 503 语义**：更新扩展/监控对健康检查的预期。
- **Email 认证**：fork 未启用 `verifySpf`/`verifyDkim` 则无需 `trustedAuthservIds`；若启用需补配置。
- **配置废弃字段**：检查 `~/.nanobot/config.json` 无 `failOnToolError`/`NANOBOT_LLM_TIMEOUT_S`。

## Testing Decisions

### 好的测试 = 外部行为，不测实现细节

聚焦"升级后 fork 特性仍对外可见"的行为断言，而非内部函数结构。

### 测试 seam（双层：纯函数单元 + 网关 WS/REST 对外接口）

**底层 seam：纯函数单元**——`tests/fork/`（`parse_nav_marker` 7 例、`mask_llm_error` 4 例）+ `tests/channels/test_fork_navigation_dispatch.py`（导航分发 3 例）。fork 逻辑全部独立可测。

**主 seam：运行中的网关（127.0.0.1:8765 / 18790）的 HTTP + WS 协议**——这是 fork 特性与扩展之间的契约面，也是 rebase 冲突影响面。已验证的端到端脚本模式：`bootstrap` 拿 token → `api_token` 访问 REST → WS 握手 → 发 `webui_request` mutation → 断言 `webui_response`。

围绕此 seam 的验证矩阵：

| 验证项 | 断言 |
|---|---|
| `new_chat` 用户映射 | `user_session_map.json` 出现 `websocket:<id>` → `user_id` 关联 |
| `session.delete` mutation | `webui_response` 返回 `{deleted: true}`，列表移除，映射清理 |
| 消息收发 | `message_accepted` 事件；会话列表 preview 更新 |
| `navigation` 事件 | agent 输出 `<!--NAV:...-->` 时扩展收到 `navigation` 事件 |
| 错误掩蔽 | 坏模型触发 LLM error → 用户侧显示"模型服务暂时不可用" |

### 自动化测试（prior art：仓库既有测试）

- `tests/agent/test_loop_runner_integration.py`（错误掩蔽断言，含 `test_streamed_flag_not_set_on_llm_error`）
- `tests/fork/` + `tests/channels/test_fork_navigation_dispatch.py`（fork 补丁层纯函数与导航分发）
- `tests/channels/test_websocket_application_boundary.py`（WS 前缀边界）
- `tests/channels/test_websocket_listener_health.py`（WS listener 健康）
- `tests/utils/test_webui_transcript.py`（transcript 兼容）
- 全量 `pytest` + `ruff` + WebUI `bun run test`/`build`
- 基线比对：rebase 前后失败集应一致（已知 9 个既有环境失败：mcp/web_fetch 网络、test_dream、tui_launcher Python 3.13）

### Chrome 扩展端到端

- reload 扩展后测：会话列表/新建/删除/切换、消息收发、工具调用（dct-north-cli）、DevTools 无 `webui_response` 不匹配告警。

## Out of Scope

- **上游新增的 TypeScript TUI 客户端**（`nanobot` 默认 TUI）：fork 日常用 `nanobot gateway` + WebUI + Chrome 扩展，TUI 本身不主动采用；仅确保入口切换不破坏现有命令。
- **PWA/移动端/新模型网关**（Eden AI、OrcaRouter、AnySearch）：上游功能，fork 不主动启用。
- **Email 认证信任锚**：fork 未使用 Email 频道，不配置 `trustedAuthservIds`。
- **macOS Seatbelt 隔离**：fork 在 macOS 桌面使用，但默认不启用隔离，仅确认不破坏现有 shell 工具。
- **SkillHub 市场/Agent 插件/浏览器 OAuth**：扩展与 WebUI 未依赖，升级后若存在由上游引入的 UI 变化，仅保持兼容不主动适配。
- **自动化（cron）视图重构**：fork 未深度使用 cron 管理界面。

## Further Notes

- **发布时机风险**：v0.3.5 于 2026-09-16 发布，当前为发布初期，可能紧随 hotfix。升级基准锁定 tag `v0.3.5` 而非 `main`，可避免 main 漂移；若 1-2 周内出现 v0.3.5.x 修复版，优先同步该版本。
- **备份与回滚**：rebase 前 `git branch backup-main-before-v035`；升级完成后可删除。`--force-with-lease` 推送 origin + gitlab。
- **扩展不在 git 仓库**：dct-nanobot 位于 `~/.nanobot/workspace/chrome-extension/`，rebase 不触及；但 WS 协议若在 v0.3.5 变化（`WebUICommandRouter` 演进），需实测确认。
- **前置知识**：fork 补丁层重构（`.scratch/fork-patch-layer/`）已把 fork 逻辑独立成 `nanobot/fork/` 包，升级冲突解决 = 按 `docs/fork-integration.md` 清单重新贴回锚点，而非重做移植。上次 rebase（到 `588be51d`）的 `WebUICommandRouter` 冲突解决经验仍可参考。