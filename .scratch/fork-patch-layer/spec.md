---
labels: [ready-for-agent]
---

# Spec: Fork 补丁层（统一抽离本地修改，最小化上游 rebase 冲突）

## Problem Statement

fork 目前有 10 个文件相对上游做了修改（249 行新增）。这些修改以**内联侵入**方式散布在上游函数体内部：NAV 标记解析、LLM 错误掩蔽、CORS 响应头、用户会话映射、navigation 事件分发。每次同步上游（如 v0.3.5 的 166 个提交）时，只要上游重构了这些函数（`_run_agent_loop`、`send_projected_message`、`http_response`、`_dispatch_envelope`），fork 的内联修改就会产生结构性冲突，需要逐个重新定位、重新移植——上次 rebase 已为此花费大量精力。

根因：**fork 特性与上游代码的"接缝"太大**。冲突不是"一两行调用"的冲突，而是"整块逻辑嵌入上游函数中途"的冲突，rebase 时无法自动区分哪些是 fork 的、哪些是上游的。

## Solution

将 fork 的本地修改按形态分类抽离到统一的 **`nanobot/fork/` 补丁层**：

- **纯逻辑（可完整抽离）**：NAV 解析、LLM 错误掩蔽 → 提取为纯函数，放进 `nanobot/fork/`，上游文件中只留 **1 行调用**。
- **数据/流程插入（只能缩小接缝）**：CORS 头、navigation 分发、用户映射调用 → 函数/helper 独立成模块，调用点保留，但在调用点旁加 **`# FORK-HOOK` 注释锚点**，方便 rebase 时照单定位。
- **已独立（保持）**：`user_session_map.py` 已是独立模块，仅需迁移到 `nanobot/fork/` 统一归属（或 re-export）。

配套建立 **`docs/fork-integration.md`** 调用点清单（文件+位置+目的）和 **`git rerere`** 冲突复用，使每次 rebase 的冲突解决从"重做移植"降为"照单粘贴"。

## User Stories

1. As a fork maintainer, I want all fork-specific logic to live in one `nanobot/fork/` package, so that upstream rebase never touches my logic files.
2. As a fork maintainer, I want the NAV marker parser (`<!--NAV:{json}-->`) to be a pure function, so that `loop.py` only contains one call instead of the inline parse block.
3. As a fork maintainer, I want the LLM error masking to be a pure function, so that the error-masking policy is testable in isolation without spinning up the agent loop.
4. As a fork maintainer, I want every remaining inline call point to carry a `# FORK-HOOK` anchor comment, so that a rebase conflict can be located and re-applied quickly.
5. As a fork maintainer, I want a `docs/fork-integration.md` that lists every fork call point (file, location, purpose), so that rebase conflict resolution is checklist-driven.
6. As a fork maintainer, I want `git rerere` enabled, so that recurring conflict resolutions are replayed automatically.
7. As a fork maintainer, I want the CORS behavior unchanged after extraction, so that the Chrome extension still reaches the gateway cross-origin.
8. As a fork maintainer, I want the user-session mapping behavior unchanged after extraction, so that session filtering by user still works.
9. As a fork maintainer, I want the navigation event dispatch behavior unchanged after extraction, so that the extension still receives `navigation` events.
10. As a fork maintainer, I want the CLI App local-install fallback to remain untouched by this refactor, so that `dct-north-cli` keeps working.
11. As a fork maintainer, I want the refactor to be behavior-preserving (no functional change), so that the existing test suite and runtime verification still pass without modification.
12. As a fork maintainer, I want the refactor to be reviewable as a mechanical move, so that I can trust it did not alter semantics.

## Implementation Decisions

### 目标包结构

```
nanobot/fork/
  __init__.py          # 导出公共 API：parse_nav_marker, mask_llm_error, ...
  navigation.py        # parse_nav_marker(text) -> (dict|None, str) 纯函数
  llm_error.py         # mask_llm_error(final_content: str) -> str 纯函数
  user_session.py      # 从 nanobot/webui/user_session_map.py 迁入（或 re-export 保持旧 import）
  cors.py              # CORS_ALLOW_ALL 常量 + 响应头 helper
```

> 决策：`user_session_map.py` 若已有独立文件且运行稳定，**不强制迁移**，可在 `nanobot/fork/__init__.py` 中 `re-export` 统一对外出口；是否物理移动取决于 `docs/changes-since-origin-main.md` 与扩展的 import 依赖。

### 修改点分类与处理

| 修改 | 位置 | 形态 | 处理 |
|---|---|---|---|
| NAV 解析（`<!--NAV:-->` → dict + 剥离） | `agent/loop.py`（2 处：`_run_agent_loop` 流式 + `_persist_turn`） | 纯函数 | 提取 `parse_nav_marker()` → 调用点 1 行 |
| LLM 错误掩蔽 | `agent/loop.py` | 纯函数 | 提取 `mask_llm_error()` → 调用点 1 行 |
| CORS 响应头 | `webui/http_utils.py`、`webui/ws_http.py` | 侵入签名（`cors_origin` 参数） | helper 抽到 `fork/cors.py`；签名参数保留，旁加 `# FORK-HOOK` |
| 用户映射关联 | `webui/inbound_commands.py` | 流程插入 | 调用已独立；加 `# FORK-HOOK` |
| 用户映射过滤/dissociate | `webui/ws_http.py` | 流程插入 | 同上 |
| navigation 事件分发 | `channels/base.py`（`send_navigation`）+ `channels/manager.py` + `channels/websocket/runtime.py` | 接口 + 流程插入 | `send_navigation` 保持接口；调用点加 `# FORK-HOOK` |
| CLI App 本地回退 | `apps/cli/service.py` | 纯新增方法 | **不动**（v0.3.5 零冲突，保持现状） |

### 调用点锚点规范

所有保留在上游文件中的 fork 调用行，紧邻上方加固定格式注释：

```python
# FORK-HOOK: <fork-feature-name> — see docs/fork-integration.md
```

每个 `fork-feature-name` 唯一，与 `docs/fork-integration.md` 清单条目一一对应。

### 文档：docs/fork-integration.md

| 列 | 内容 |
|---|---|
| hook id | `fork-nav-stream`、`fork-nav-persist`、`fork-err-mask`、`fork-cors-*`、`fork-user-map-*`、`fork-nav-send` |
| 文件 | 上游文件路径 |
| 锚点 | `# FORK-HOOK` 注释旁的可搜索字符串 |
| 目的 | 一句话说明 |
| rebase 检查项 | 该 hook 在上游新代码中的落点 |

### git 配置

```bash
git config rerere.enabled true
```

### 明确不做的事

- 不把 CORS 参数从 `http_response()`/`_http_error()` 签名移除（那会破坏行为且无法消除签名冲突本质）。
- 不引入插件注册机制/动态 patch 上游类（过度设计，且 asyncio 生命周期下脆弱）。
- 不重写 `user_session_map.py` 的存储格式。

## Testing Decisions

### 好的测试 = 外部行为不变

本次重构是**行为保持型**重构，测试目标是"重构前后行为逐位一致"，而非新功能测试。

### 测试 seam（单一 seam：纯函数单元 + 网关 WS/REST 行为）

1. **纯函数单元测试**（新 seam，最低层）：
   - `parse_nav_marker()`：输入含/不含/畸形 `<!--NAV:...-->` 文本 → 断言返回的 `(nav_dict, cleaned_text)`。
   - `mask_llm_error()`：断言错误文本被替换为固定文案。
   - prior art：`tests/utils/test_webui_transcript.py` 的纯函数测试风格。

2. **网关行为回归**（既有 seam，最高层）：
   - CORS：`curl` 带 `Origin` 请求 bootstrap → 断言 `Access-Control-Allow-Origin` 头。
   - 用户映射：`new_chat` + 检查 `user_session_map.json`。
   - navigation：agent 输出 NAV 标记 → 断言 WS `navigation` 事件。
   - 错误掩蔽：坏模型触发 → 用户侧固定文案。
   - 复用 `.scratch/sync-upstream-v0.3.5/spec.md` 中已确立的端到端脚本模式。

3. **回归基线**：重构前后 `pytest` 失败集应**完全一致**（当前已知 9 个既有环境失败），新增失败即重构 bug。

## Out of Scope

- 不修复现有 9 个既有测试失败（网络环境/上游兼容，非本 spec 范围）。
- 不实现上游 v0.3.5 的新功能（TUI、SessionStore 等）——本 spec 仅重构 fork 修改的组织形式。
- 不改变 fork 特性的行为语义。
- 不迁移 Chrome 扩展代码。
- 不引入依赖注入框架或插件系统。

## Further Notes

- 本重构是 **v0.3.5 升级的前置工作**：先抽离（零行为变化、可独立验证），再 rebase v0.3.5（冲突面已缩到调用点），顺序不可反。
- `git rerere` 需要从启用时起积累冲突解决方案；首次 rebase 仍需手动解决，后续复用。
- 若 `user_session_map.py` 物理迁移到 `nanobot/fork/`，需同步更新 `docs/changes-since-origin-main.md` 与任何硬编码 import（含扩展侧）。
- 参考 prior art：上游自己的 `refactor(webui): isolate websocket application orchestration (#5548)` 也是"逻辑抽独立模块 + 薄委托调用点"的同款模式，本 spec 与上游架构方向一致。