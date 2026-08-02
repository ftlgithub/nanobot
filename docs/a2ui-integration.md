# nanobot × A2UI 集成可行性报告

> 状态：可行性评估（2026-08-02）
> 范围：本报告只做设计评估，不包含代码改动
> 结论先行：**集成可行，接缝清晰**。nanobot 已有一个未使用的 `AgentUIBlob {kind, data}` 扩展点，正好承载 A2UI 声明式 UI payload。

---

## 1. 背景

### 1.1 nanobot

nanobot 是轻量级开源 AI agent 框架（Python 核心 + React/TypeScript WebUI）。消息通过异步 `MessageBus` 在通道（Telegram/Discord/WebSocket…）与 agent 核心之间流转：

```
Channel → publish_inbound → MessageBus → AgentLoop → AgentRunner(LLM) → OutboundMessage → Channel → WebUI
```

关键事实（已在源码中核实）：

- `OutboundMessage` 携带 `metadata: dict`，其中 `OUTBOUND_META_AGENT_UI = "_agent_ui"` 已定义为结构化 UI blob 的元数据键，WebSocket 通道会将其序列化为 `agent_ui` 字段（`nanobot/channels/websocket/runtime.py:1061`）。
- WebUI 侧类型已有 `AgentUIBlob { kind: string; data?: unknown }`（`webui/src/lib/types.ts`），支持任意自定义 `kind`。
- **该扩展点目前未被任何通道使用**——是一个为富客户端预留的现成接缝。
- WebUI 为 React 18.3.1 + Tailwind 3，无 zod。
- 工具系统通过 `pkgutil` 扫描 `nanobot/agent/tools/` 自动发现，agent 为 tool-driven 架构。
- Python 侧已内置 `pydantic` 与 `json-repair`（可修复 LLM 输出 JSON 瑕疵）。

### 1.2 A2UI

A2UI（Agent-to-User Interface）是一个开放标准 + 多语言实现：agent 以**声明式 JSON**描述 UI 意图，客户端用本地组件库渲染。核心哲学：**"safe like data, but expressive like code"**——UI 是数据而非可执行代码，客户端只渲染目录（catalog）中预批准的组件。

协议版本以 **v0.9.1** 为准（A2UI 官方 AGENTS.md 权威声明；v1.0 仍为 RC）。

A2UI 消息模型（v0.9）：

| 方向 | 消息 | 作用 |
|------|------|------|
| agent → 客户端 | `createSurface` | 创建一个 surface（含 catalogId、可选主题） |
| agent → 客户端 | `updateComponents` | 填充/更新组件树（扁平组件列表 + ID 引用） |
| agent → 客户端 | `updateDataModel` | 更新数据绑定（path + value） |
| agent → 客户端 | `deleteSurface` | 销毁 surface |
| 客户端 → agent | `action` | 用户交互回传（`{name, context}`） |

A2UI 官方 Python 生态：

- `a2ui-agent-sdk`（v0.5.0）：完整 SDK，含 prompt 生成、Direct JSON/Express/Atom 解析器、流式支持——但**强依赖 `google-adk` + `google-genai` + `a2a-sdk` + `antlr4`**，且集成模式绑定 Google ADK 的 `LlmAgent`。
- `a2ui-core`（~50KB）：轻量核心，含 catalog schema 校验（`A2uiCatalog.validator`）、pydantic 模型。新增传递依赖仅 `jsonschema` + `referencing`。

A2UI 官方前端生态：

- `@a2ui/web_core`（v0.10.6）：**纯框架无关 TS 库**，无 peerDependencies，自带依赖仅 `zod` / `@preact/signals-core` / `date-fns` / `zod-to-json-schema`。提供 `MessageProcessor`（协议解析与状态管理）、`Catalog`（组件注册与 schema 校验）、`GenericBinder`（数据绑定与双向同步）。
- `@a2ui/react`（v0.10.2）：React 渲染层，**要求 React ≥19.2.7**（peer dependency）。

---

## 2. 集成架构总览

```
┌─ nanobot 后端 (Python) ─────────────────────────────────────────────────┐
│                                                                          │
│  LLM ──(调用)──> a2ui 工具 (nanobot/agent/tools/a2ui.py)                │
│                      │ 接收结构化 JSON，a2ui-core 校验                   │
│                      ▼                                                  │
│              OutboundMessage.metadata["_agent_ui"] = {                  │
│                  kind: "a2ui",                                          │
│                  data: [ {createSurface}, {updateComponents}, ... ]     │
│              }                                                          │
│                      │                                                  │
└──────────────────────┼──────────────────────────────────────────────────┘
                       ▼
              MessageBus / WebSocket 通道 (serialize agent_ui)
                       │
┌─ nanobot WebUI (React 18) ───────────────────────────────────────────────┐
│                                                                          │
│  收到 message 帧 ──> 解析 agent_ui ──> MessageProcessor.processMessages()│
│                                           │ (web_core, 增量更新)         │
│                                           ▼                              │
│                                    SurfaceModel ──> A2UISurface (自研)   │
│                                           │ 用户点击/提交表单             │
│                                           ▼                              │
│                             {version, action:{name, context}}           │
│                                           │                              │
└───────────────────────────────────────────┼──────────────────────────────┘
                                            ▼
              InboundMessage (metadata: {a2ui_action: {...}}, content: 可读摘要)
                                            │
                                            ▼
                                       AgentLoop (LLM 响应)
```

**核心思路**：复用 nanobot 现有的 `_agent_ui` 元数据扩展点作为 A2UI 传输通道，后端用一个 `a2ui` 工具 + 轻量 `a2ui-core` 校验发射 payload，前端用框架无关的 `@a2ui/web_core` 做协议处理 + 自研薄渲染层展示，用户动作以结构化 inbound 消息回传。

---

## 3. 协议 ↔ nanobot 消息映射

### 3.1 agent → WebUI（A2UI payload）

| A2UI 层 | nanobot 层 |
|---------|-----------|
| A2UI JSON 消息数组 | `OutboundMessage.metadata[OUTBOUND_META_AGENT_UI]` = `{"kind": "a2ui", "data": [A2uiMessage...]}` |
| WebSocket 帧 `agent_ui` 字段 | 已实现（`websocket/runtime.py` 透传 metadata） |
| WebUI 类型 | 已有 `AgentUIBlob`，`kind === "a2ui"` 时进入 A2UI 渲染管线 |

增量更新语义：`data` 是 **A2UI 消息数组**，一条 outbound message 可携带 `createSurface → updateComponents → updateDataModel` 多步增量；跨回合也自然支持（上一回合 createSurface，下一回合 updateComponents 只改数据）。增量处理的全部复杂性（surface 状态、组件树 diff、数据绑定）由 `web_core` 的 `MessageProcessor` 承担。

### 3.2 WebUI → agent（action 回传）

| A2UI 层 | nanobot 层 |
|---------|-----------|
| `{version, action: {name, context}}` | InboundMessage，`metadata["a2ui_action"]` 存结构化 payload；`content` 存人类可读摘要 |
| 摘要示例 | `[a2ui] 用户点击了"提交预订"按钮，表单：日期=3月1日，人数=2` |

回传走 LLM：摘要文本进入 LLM 上下文，LLM 决定如何响应（可再调用 `a2ui` 工具更新界面、追问信息、或直接完成任务）。摘要同时保证：非 WebUI 客户端也能看到"用户点了 X"，且会话历史可读可回放。

### 3.3 非 WebUI 通道

`agent_ui` 仅由 WebSocket 通道序列化，其他通道（Telegram/Discord/Feishu…）的 `send()` 只发送 `content` 文本——**自动降级为纯文本，无需额外工作**。

---

## 4. 组件映射表（V1 最小核心子集）

前端自研渲染层（React 18），V1 只实现 6 个核心组件：

| A2UI basicCatalog 组件 | React 18 实现 | 覆盖场景 |
|------------------------|---------------|----------|
| `Row` | flex 横向布局容器 | 按钮组、并排字段 |
| `Column` | flex 纵向布局容器 | 表单、卡片内容 |
| `Text` | 文本渲染（支持 variant/动态值） | 标题、说明、动态数据 |
| `Image` | 图片渲染（含 URL 校验） | 展示图片/预览 |
| `Button` | 按钮（action 绑定 → 触发回传） | 操作触发 |
| `TextField` | 输入框（双向数据绑定 → 表单收集） | 动态数据收集 |

其余 12 个组件（List/Card/Tabs/Modal/Divider/Icon/Video/AudioPlayer/CheckBox/ChoicePicker/Slider/DateTimeInput）列入 V2 roadmap。

组件注册走 `web_core` 的 `Catalog` 机制：自研组件定义为 `ReactComponentImplementation`（含 name/schema/render），schema 用 zod 声明——天然获得 payload 校验与 `GenericBinder` 的双向绑定能力。

---

## 5. 详细设计

### 5.1 后端：a2ui 工具

- 新增 `nanobot/agent/tools/a2ui.py`，通过工具注册表自动发现。
- 工具 schema：接收 `version`（默认 "0.9"）+ A2UI 消息数组（`createSurface`/`updateComponents`/`updateDataModel`/`deleteSurface`）。
- 校验：用 `a2ui-core` 的 `A2uiCatalog.validator` 校验 payload；校验失败时把具体错误（如"第 3 个组件缺 id"）返回给 LLM 重试。
- 发射：校验通过后，把 `{"kind": "a2ui", "data": messages}` 写入当前回合 outbound message 的 `metadata[OUTBOUND_META_AGENT_UI]`。
- 依赖：`a2ui-core` 作为 **optional extra**（`pyproject.toml` 中与 langfuse/pdf 等一致），核心不依赖，启用 A2UI 才安装。
- 工具默认注册，LLM 自由决定何时调用（工具描述明确"用户请求表单、卡片、可交互界面时使用；普通文本回复不要用"）。

### 5.2 前端：自研渲染层

- 新增依赖：`@a2ui/web_core`（纯 TS，无 peerDeps，React 18 兼容）。**不安装** `@a2ui/react`（规避 React 19 升级）。
- 全局单例 `MessageProcessor([customCatalog], actionCallback)`：
  - 收到含 `agent_ui.kind === "a2ui"` 的消息 → `processor.processMessages(data)`。
  - 订阅 `onSurfaceCreated` / `onSurfaceDeleted` 维护 surface 列表状态。
- 自研 `A2UISurface` 组件（React 18 + useSyncExternalStore 响应 surface 状态变化），按 4 节组件映射表渲染。
- 动作回调：用户交互 → `{version, action}` → 经 `NanobotClient` 以 inbound message 发送（`metadata.a2ui_action` + 摘要 `content`）。

### 5.3 状态与历史

- A2UI payload **不入 LLM 上下文**：session history 只存 `content` 摘要，payload 只经 metadata 实时传递。
- UI 状态**不持久化**：刷新页面后 UI 消失（V2 可加 localStorage 恢复）。web_core 的 surface 状态天然在客户端内存中，服务端无需镜像状态机。

---

## 6. 依赖清单

| 侧 | 新增依赖 | 传递依赖 | 大小量级 |
|----|----------|----------|----------|
| Python（可选 extra） | `a2ui-core>=0.1.1,<0.2.0` | jsonschema、referencing（pydantic 已有） | ~50KB |
| WebUI | `@a2ui/web_core` | zod、@preact/signals-core、date-fns、zod-to-json-schema | 轻量纯 TS |

**明确排除**：
- `a2ui-agent-sdk`（Python）：强拉 `google-adk` + `google-genai` + `a2a-sdk` + `antlr4`，且集成模式绑定 ADK 的 `LlmAgent`，与 nanobot 自有 `AgentRunner` 架构不匹配。
- `@a2ui/react`（前端）：要求 React ≥19.2.7，升级整个 WebUI 成本远超收益。

---

## 7. 风险清单

| 风险 | 等级 | 缓解 |
|------|------|------|
| 自研渲染层工作量（React 18 不直接用官方渲染器） | 中 | V1 只做 6 个核心组件；组件 schema 用 zod 声明，注册走 web_core Catalog 机制 |
| A2UI 仍为 early stage（v0.9.x，v1.0 未定稿） | 中 | 锁定 v0.9.1；接口集中在工具 + 自研渲染层两个薄点上，协议升级时改动可控 |
| LLM 误触发 a2ui 工具（token 浪费） | 低 | 工具描述写明触发场景；实测有问题再考虑按消息来源（仅 WebUI）注入工具 |
| 刷新页面丢失 UI 状态 | 低 | V1 接受为已知限制；V2 加 localStorage 持久化 |
| 恶意/异常 agent 输出 payload（XSS 等） | 低 | A2UI 是声明式数据非代码；仅渲染 catalog 白名单组件；Image 等 URL 需校验；遵循"agent 输出视为不可信输入"原则 |
| payload 过大（组件树膨胀） | 低 | a2ui-core schema 校验 + 前端渲染上限（可后续加） |
| 多 surface 并发管理 | 低 | web_core 的 `onSurfaceCreated/Deleted` 已处理生命周期 |

---

## 8. V2 Roadmap

- 补齐 basicCatalog 剩余 12 个组件（List/Card/Tabs/Modal/Icon/Video/AudioPlayer/CheckBox/ChoicePicker/Slider/DateTimeInput…）。
- localStorage 恢复 UI 状态（刷新不丢）。
- 按消息来源启用工具（仅 WebUI 会话注入 a2ui 工具）以进一步省 token。
- 实验性推理格式评估（Atom/Express 更省 token，适合受限上下文）。
- 自定义 nanobot 专属 catalog 组件（如会话管理、工具调用结果可视化）。

---

## 9. 决策记录

| # | 决策点 | 选择 |
|---|--------|------|
| 1 | 目标范围 | 可行性报告（不动代码） |
| 2 | 结论方向 | 集成可行 |
| 3 | 前端渲染策略 | React 18 + `@a2ui/web_core` + 自研薄渲染层（不装 `@a2ui/react`） |
| 4 | 后端依赖 | `a2ui-core` 可选 extra（排除 `a2ui-agent-sdk`） |
| 5 | 发射机制 | `a2ui` 工具调用（结构化 JSON + 校验 + 错误反馈重试） |
| 6 | 动作回传 | 结构化消息注入（metadata `a2ui_action` + content 摘要，走 LLM） |
| 7 | 组件范围 | V1 最小核心子集 6 组件（Row/Column/Text/Image/Button/TextField） |
| 8 | 增量更新 | 完整增量（`agent_ui.data` = A2UI 消息数组） |
| 9 | 历史/上下文 | payload 不入 LLM 上下文，UI 状态不持久化 |
| 10 | 工具触发 | 默认注册、LLM 自由决定 |
| 11 | 交付形式 | 本文件（nanobot 仓库）+ Obsidian vault 副本 |

---

## 附：已核实的源码事实

- `nanobot/bus/events.py`：`OUTBOUND_META_AGENT_UI = "_agent_ui"`（第 13 行），OutboundMessage 含 `metadata` dict。
- `nanobot/channels/websocket/runtime.py`：第 1061-1063 行把 `metadata["_agent_ui"]` 透传为 WebSocket 帧的 `agent_ui` 字段。
- `nanobot/channels/websocket/tests/test_websocket_channel.py:1293`：已有 `test_send_progress_includes_agent_ui_blob` 测试。
- `webui/src/lib/types.ts`：`AgentUIBlob { kind: string; data?: unknown }`（第 263-267 行）。
- `webui/package.json`：React `^18.3.1`，无 zod。
- A2UI `renderers/web_core/package.json`：v0.10.6，无 peerDependencies，依赖 zod/signals-core/date-fns/zod-to-json-schema。
- A2UI `renderers/react/package.json`：v0.10.2，peerDependencies 要求 react ^19.2.7。
- A2UI `agent_sdks/python/a2ui_agent/pyproject.toml`：`a2ui-agent-sdk` 依赖 google-adk/genai/a2a-sdk/antlr4。
- A2UI `agent_sdks/python/a2ui_core/`：轻量核心（jsonschema/pydantic/referencing 量级）。

---

## 附 2：决策过程问答记录（完整版）

> 以下为 2026-08-02 grilling 逐问决策的完整过程记录，含每问的选项、推荐理由与最终选择，供日后查证。

### Q1 目标范围：你要的是什么？

**背景**：你问"nanobot 能否集成 A2UI"，属于可行性不确定型问题。

**选项**：
1. **完整生产级集成** — 新 a2ui 工具 + WebUI 渲染 + 动作回传 + 文档/测试。数周工作量。
2. **可运行 PoC** — 最小端到端切片（一个 A2UI 卡片 + 一个工具 + 按钮回传），验证接缝。几天工作量。
3. **可行性报告** — 只写集成设计（协议映射、组件映射、风险清单），不动代码。

**我的推荐**：选项 2（PoC）。垂直切片最快验证可行性，且能先测出 React 19 这个最大风险点。

**你的选择**：**3（可行性报告）**

---

### Q2 前端渲染策略：React 18 vs 19 冲突怎么解决？

**背景**：nanobot WebUI 是 React 18.3.1，官方 `@a2ui/react` 要求 React ≥19.2.7。

**选项**：
- **A. 升级 webui 到 React 19 + 官方 `@a2ui/react`** — 官方渲染器、组件全、样式现成；代价是全局升级 Radix UI 等依赖兼容性验证，风险大，A2UI 本身还是 early stage。
- **B. 保持 React 18，用框架无关的 `@a2ui/web_core` + 手写渲染层** — web_core 提供 MessageProcessor/Catalog/GenericBinder（协议核心），渲染层自己写（18 个组件本身简单）。工作量中等，不碰主框架。
- **C. 零前端依赖纯手写** — 最轻但等于自己造渲染器，偏离"集成 A2UI"本意。

**我的推荐**：B。nanobot 定位 ultra-lightweight，升级 React 19 代价远大于收益；web_core 恰好框架无关。

**你的选择**：**B**

---

### Q3 后端依赖策略：Python 侧怎么发射 A2UI？

**背景**：nanobot 已内置 pydantic + json-repair，没有 jsonschema/antlr4/google-adk。

**选项**：
- **A. 完整 `a2ui-agent-sdk`（v0.5.0）** — 官方 prompt 生成/解析/流式/校验；但强拉 google-adk + google-genai + a2a-sdk + antlr4，且集成方式绑定 ADK 的 LlmAgent，与 nanobot 自己的 AgentRunner 架构不匹配。
- **B. 只加 `a2ui-core`（~50KB）** — 官方 catalog schema 校验 + pydantic 模型；新增依赖仅 jsonschema + referencing。做成 optional extra（与 langfuse/pdf 一致），核心不依赖。
- **C. 零依赖** — 完全自己定义结构，校验甩给前端 web_core。

**我的推荐**：B。轻量、官方校验放后端拦截坏 payload、符合 lightweight 哲学；明确排除 a2ui-agent-sdk。

**你的选择**：**B**

---

### Q4 发射机制：LLM 怎么产出 A2UI？

**选项**：
- **A. 系统提示注入** — A2UI 说明+示例进 system prompt，LLM 在文本里输出 `<a2ui>{json}</a2ui>` 块，后端提取解析。贴合官方做法、支持流式；但解析自由文本易错、全对话耗 token。
- **B. 工具调用（a2ui 工具）** — LLM 传结构化 JSON，工具 catalog 校验后挂 `_agent_ui`。错误可反馈给 LLM 重试、与现有工具体验一致；一次调用=一次 UI 快照，增量靠多次调用。
- **C. 两者结合** — 工具为主，prompt 只放一行提示。

**我的推荐**：B。nanobot 是 tool-driven 架构，工具接入零摩擦；这正是 A2UI 官方在 ADK 里的模式（SendA2uiToClientToolset）。

**你的选择**：**B**

---

### Q5 动作回传：用户点击/表单提交怎么回到 agent？

**选项**：
- **A. 结构化消息注入（走 LLM）** — metadata 带 `a2ui_action` payload + content 放人类可读摘要（如 `[a2ui] 用户点击了"提交预订"按钮…`），注入 LLM 上下文由 LLM 响应。对现有管线零改动、历史可读、保留灵活性。
- **B. 专用 inbound 事件类型（仍走 LLM）** — 语义清晰但需改 WebSocket 协议 + agent loop inbound 分支，工作量大。
- **C. 不经 LLM 直接路由到处理器** — 低延迟省 token，但只适用于预定义固定交互，失去动态响应能力。

**我的推荐**：A。零改动、历史可读可回放、保留 LLM 智能响应的核心价值。

**你的选择**：**A**

---

### Q6 组件范围：手写渲染层支持哪些 A2UI 组件？

**选项**：
- **A. 全量 basicCatalog 18 组件** — Row/Column/List/Card/Tabs/Modal/Divider/Text/Image/Icon/Video/AudioPlayer/Button/TextField/CheckBox/ChoicePicker/Slider/DateTimeInput。完整但 Tabs/Modal/DateTimeInput 工作量大。
- **B. 最小核心子集 6 组件（推荐）** — Row/Column/Text/Image/Button/TextField。覆盖动态数据收集、信息卡片、操作触发三大场景；其余 12 个列 V2。
- **C. 通用 JSON 树查看器** — 任何 payload 都能显示但不像真实 UI。

**我的推荐**：B。工作量与演示效果平衡最佳。

**你的选择**：**B**

---

### Q7 增量更新 vs 一次性快照？

**背景**：A2UI 核心卖点是增量更新（createSurface → updateComponents → updateDataModel）。

**选项**：
- **A. 一次性快照** — 每回合一个完整 payload，WebUI 整块重绘。改动最小但失去核心价值。
- **B. 完整增量（推荐）** — `agent_ui.data` = A2UI 消息数组，一条消息可带多步增量；跨回合自然支持。增量复杂性全部由 web_core 的 MessageProcessor 承担，只是传数组而已。
- **C. 折中** — 首轮全量、后续增量，本质是 B 的特例。

**我的推荐**：B。成本接近 A，却完整保留 A2UI 增量更新的核心价值。

**你的选择**：**B**

---

### Q8 A2UI payload 与会话历史 / LLM 上下文的关系？

**选项**：
- **A. 不持久化，payload 不入 LLM 上下文（推荐）** — A2UI JSON 只经 metadata 实时传 WebUI；history 只存 content 摘要；LLM 需要 UI 就重新 emit。刷新丢 UI（接受为限制）。最省 token、历史干净。
- **B. payload 原样入 history** — 简单但组件树 JSON 反复重放，token 浪费大。
- **C. 服务端单独持久化 UI 状态** — 刷新可恢复，但 web_core 状态在客户端，服务端需镜像状态机，工作量大。

**我的推荐**：A。A2UI 的哲学是"UI 是瞬态表现层"，组件树 JSON 对 LLM 无思考价值。

**你的选择**：**A**

---

### Q9 a2ui 工具触发策略？

**选项**：
- **A. 默认注册，LLM 自由决定（推荐）** — 与其他工具一致，工具描述写明"用户请求表单/卡片/可交互界面时用"。零配置零状态。
- **B. 按会话/配置启用** — 可控但引入配置负担。
- **C. 按消息来源启用（仅 WebUI）** — 理论省 token，但工具注册是全局的，动态注入需改 agent 上下文构建逻辑。

**我的推荐**：A。与 nanobot 工具自动发现模式一致；实测误触发严重再考虑 C。

**你的选择**：**A**

---

### Q10 报告交付形式与存放位置？

**选项**：
- **A. 独立 Markdown 放 nanobot 仓库 docs/（推荐）** — 可留存、可进 git、可直接指导后续实施。不实施删掉成本也低。
- **B. 仓库外（如 /tmp）** — 不污染仓库但不在版本控制、易丢。
- **C. 对话直接输出** — 最轻但长报告不便翻阅转发。

**我的推荐**：A。报告即设计文档，放仓库能直接指导 V2 开发。

**你的选择**：**A**

---

### Q11 补充：Obsidian 副本

**你的补充要求**：报告同时在 Obsidian 笔记中存一份。

**执行**：确认 vault 位于 `/Users/fengtailong/Documents/Obsidian Vault`，在根目录创建本文件副本（即当前这份笔记），与仓库版 diff 一致。

**你的选择**：**采纳**

---

## 附 3：共识总结（问答结束后确认）

| # | 决策点 | 选择 |
|---|--------|------|
| 1 | 目标范围 | 可行性报告（不动代码） |
| 2 | 结论方向 | 集成可行 |
| 3 | 前端渲染策略 | B：React 18 + web_core + 手写渲染层 |
| 4 | 后端依赖 | B：a2ui-core 可选 extra |
| 5 | 发射机制 | B：a2ui 工具调用 |
| 6 | 动作回传 | A：结构化消息注入走 LLM |
| 7 | 组件范围 | B：最小核心子集 6 组件 |
| 8 | 增量更新 | B：完整增量（消息数组） |
| 9 | 历史/上下文 | A：payload 不入 LLM 上下文 |
| 10 | 工具触发 | A：默认注册、LLM 自由决定 |
| 11 | 交付形式 | 本报告 + Obsidian 副本 |
