---
title: "nanobot × A2UI 集成"
tracker: local (.scratch/a2ui-integration)
labels: [ready-for-agent]
feature: a2ui-integration
date: 2026-08-02
status: ready-for-agent
---

# 需求报告：nanobot × A2UI 集成

## 问题陈述

nanobot 目前只能以纯文本回复用户，即使 agent 有结构化的数据要展示（表单、卡片、可交互控件），也只能把它们塞进 Markdown 文本里。用户在 WebUI 里看到的是"一段文字描述"而不是"一个可用的界面"——动态数据收集、审批工作流、数据可视化这些场景在 nanobot 上无法落地，agent 的能力被文本通道卡住了。

A2UI（Agent-to-User Interface）是一个声明式 JSON 协议，允许 agent "说 UI"：agent 发送描述 UI 意图的 JSON，客户端用本地组件库渲染。nanobot 需要打通这条链路，让 agent 能在 WebUI 里生成可交互界面，并把用户的界面操作接回 agent 循环。

可行性已在单独报告中论证（`docs/a2ui-integration.md`）：nanobot 的 `OutboundMessage.metadata` 已有 `_agent_ui` 扩展点（WebSocket 通道会透传为 `agent_ui` 帧字段，WebUI 类型已有 `AgentUIBlob {kind, data}`），接缝清晰，集成可行。

## 解决方案

在 nanobot 中新增一条 A2UI 渲染链路：

1. **发射**：新增 `a2ui` 工具，LLM 通过工具调用提交结构化 A2UI JSON（v0.9 协议：`createSurface` / `updateComponents` / `updateDataModel` / `deleteSurface`）。工具用 `a2ui-core` 的 catalog schema 校验 payload，校验失败把具体错误反馈给 LLM 重试。
2. **传输**：校验通过的 payload 以 `{"kind": "a2ui", "data": [A2uiMessage...]}` 写入 outbound message 的 `_agent_ui` 元数据，经现有 WebSocket 通道透传到 WebUI。`data` 是 A2UI 消息数组，支持增量更新（createSurface → updateComponents → updateDataModel 可分多步、跨回合）。
3. **渲染**：WebUI 依赖框架无关的 `@a2ui/web_core`（MessageProcessor 处理协议与状态、Catalog 注册组件、GenericBinder 做数据绑定），自研薄渲染层（React 18）把 surface 渲染为 UI。V1 只实现 6 个核心组件：Row / Column / Text / Image / Button / TextField。
4. **回传**：用户在 UI 上的操作（按钮点击、表单提交）以 `{version, action: {name, context}}` 形式，通过 inbound message 回传——`metadata` 带结构化 `a2ui_action` payload，`content` 放人类可读摘要，注入 LLM 上下文由其决定如何响应。

非 WebUI 通道（Telegram/Discord 等）不渲染 A2UI，自动降级为 `content` 纯文本。

## 用户故事

1. 作为 agent，我希望通过工具调用发射结构化 UI payload，以便向用户展示可交互界面而非纯文本。
2. 作为 agent，我希望我的 UI payload 在到达客户端之前经过 schema 校验，以便格式错误的 UI 定义能被拦截并修复，而不是破坏客户端。
3. 作为 agent，我希望在 UI payload 非法时收到可操作的校验错误，以便在下次工具调用时自我纠正。
4. 作为 agent，我希望能增量更新 UI（先创建 surface，再填充组件，最后更新数据），以便用户看到渐进式渲染，而不是等待整棵 UI 树生成。
5. 作为 agent，我希望能在后续回合更新已存在的 surface，以便长时交互无需重建界面即可刷新 UI。
6. 作为 agent，我希望通过对话上下文得知用户何时与我的 UI 交互（按钮点击 / 表单提交），以便对用户的操作做出智能响应。
7. 作为用户，我希望 agent 的回复能在 WebUI 中渲染为可交互 UI（卡片、表单、按钮），以便我不仅能打字，还能与 agent 直接交互。
8. 作为用户，我希望点击 agent 渲染的按钮、提交表单时，我的操作能回传给 agent 并得到相应反应。
9. 作为用户，我希望携带 UI 的消息在非 WebUI 通道上仍能显示纯文本降级内容，以便同一段对话在任何地方都可读。
10. 作为 WebUI 开发者，我希望 A2UI 渲染复用现有的 `agent_ui` 消息字段，以便 WebSocket 通道无需任何协议改动。
11. 作为 WebUI 开发者，我希望集成框架无关的 `@a2ui/web_core` 而不升级 React，以便 WebUI 技术栈（React 18）保持稳定。
12. 作为后端开发者，我希望 A2UI 支持放在可选依赖 extra 后面，以便 nanobot 核心安装保持轻量。
13. 作为后端开发者，我希望 `a2ui` 工具像其他工具一样自动发现，以便无需额外注册接线。
14. 作为 agent，我希望根据对话内容自行决定何时使用 `a2ui` 工具，以便只在用户要求时才生成 UI。
15. 作为用户，我希望刷新 WebUI 页面不会破坏对话，并接受临时的 agent 生成 UI 会丢失，以便核心会话历史保持完好。
16. 作为安全评审者，我希望 UI payload 被当作不可信的声明式数据处理、只从白名单组件目录渲染，以便任意 agent 生成的 UI 无法执行代码。
17. 作为开发者，我希望 Python 工具与 React 渲染器各自在其接缝处可测试，以便无需跨语言端到端测试框架即可验证集成。

## 实现决策

### 架构

- **传输**：复用 `OutboundMessage.metadata["_agent_ui"]`（`OUTBOUND_META_AGENT_UI`）——WebSocket 通道已将其序列化为 `agent_ui` 帧字段，WebUI 也已将其类型化为 `AgentUIBlob`。`kind` 取值：`"a2ui"`。`data` 是 **A2UI v0.9 消息数组**（而非单个快照），以支持增量更新。
- **协议版本**：锁定 A2UI **v0.9.1**（按 A2UI 官方权威声明为当前稳定版；v1.0 仍为 RC）。
- **非 WebUI 通道**：无需改动——只有 WebSocket 通道序列化 `agent_ui`；其他通道只发 `content` 文本，自然降级。

### 后端（Python）

- **新工具**：在工具自动发现注册表中新增 `a2ui` 工具。输入：`version`（默认 `"0.9"`）+ A2UI 消息数组。工具按 A2UI catalog schema 校验，失败时向 LLM 返回结构化错误信息供其自我纠正；成功时把校验通过的 payload 写入当前回合 outbound message 的 `_agent_ui` 元数据。
- **依赖**：`a2ui-core`（轻量；校验 + catalog + pydantic 模型）作为**可选 extra**（`a2ui` extra），与现有可选 extra（如 langfuse/pdf）保持一致。明确**不引入** `a2ui-agent-sdk`——它会拉入 `google-adk`/`google-genai`/`a2a-sdk`/`antlr4`，且其集成模型绑定 ADK 的 `LlmAgent`，与 nanobot 自有的 AgentRunner 不兼容。
- **工具注册**：与其他工具一样默认注册；由 LLM 根据工具描述自行决定何时使用（描述中写清触发场景，例如"当用户请求表单、卡片或可交互 UI 时使用"）。

### 前端（WebUI）

- **依赖**：`@a2ui/web_core`（框架无关的 TS 库，无 peer 依赖，兼容 React 18）。明确**不引入** `@a2ui/react`（要求 React ≥19.2.7——WebUI 保持在 React 18）。
- **渲染**：单一 `MessageProcessor`（来自 web_core）接收 `agent_ui.data` 数组；通过 `onSurfaceCreated`/`onSurfaceDeleted` 追踪 surface；自研薄 `A2UISurface` React 18 组件渲染 surface 树，经 `useSyncExternalStore` 响应变化。
- **组件子集（V1）**：实现 basicCatalog 中的 6 个核心组件：Row、Column、Text、Image、Button、TextField。组件经 web_core 的 `Catalog` 机制注册、用 zod schema 声明，从而获得 GenericBinder 双向绑定与 payload 校验。其余 12 个 catalog 组件推迟到 V2。
- **动作回传**：用户交互 → `{version, action: {name, context}}` → 作为 inbound message 发送，`metadata["a2ui_action"]` 存结构化内容 + `content` 存人类可读摘要；摘要即 LLM 所见内容，保证历史可读、可回放。

### 状态与历史

- **不持久化**：A2UI payload 不进入会话历史或 LLM 上下文——只有 `content` 摘要进入。UI 状态存活于 web_core 客户端的 surface 模型中。刷新页面丢失临时 UI（V1 接受的限制；localStorage 恢复为 V2）。
- **服务端不做 UI 状态镜像**：web_core 状态在客户端，服务端不复制状态机。

## 测试决策

- **指导原则**：在所选接缝处测试外部行为——不断言实现内部细节。一个好的测试应证明：合法 A2UI payload 从工具流向 `_agent_ui` 元数据 → WebUI 渲染出来；非法 payload 被拒绝并返回纠错错误；用户动作以同时含结构化与摘要内容的 inbound message 回传。
- **接缝 1 — Python 工具层**（`tests/tools/`，仿照现有工具测试，如 filesystem/message-tool 套件）：
  - 合法 A2UI 消息数组 → outbound message 的 `_agent_ui` 元数据被填充为 `{"kind": "a2ui", "data": [...]}`
  - 非法 A2UI payload（缺组件 id、未知组件类型、schema 违规）→ 工具返回纠错错误，不发射 `_agent_ui`
  - 增量多消息数组原样保留
- **接缝 2 — WebUI 渲染**（`webui/src/tests/`，沿用现有 vitest + testing-library 模式）：
  - 带 `kind === "a2ui"` 的 `agent_ui` 消息 → `MessageProcessor` 处理 → surface 出现在渲染输出中
  - `createSurface` 之后的增量 `updateComponents` / `updateDataModel` → UI 更新而不重建
  - 按钮点击 / 表单提交 → action 回调以预期的 `{name, context}` 形状触发
- **先例**：Python——`tests/channels/websocket/test_websocket_channel.py::test_send_progress_includes_agent_ui_blob`（现有 agent_ui 序列化测试）与 `tests/tools/` 套件。WebUI——`webui/src/tests/` 下基于 @testing-library/react 的组件测试。
- **不覆盖（无接缝）**：跨语言端到端测试（Python→WebSocket→WebUI 单一框架）——超出范围；两个接缝 + 现有通道序列化测试即可覆盖整条链路。

## 范围之外

- basicCatalog 其余 12 个组件（List/Card/Tabs/Modal/Divider/Icon/Video/AudioPlayer/CheckBox/ChoicePicker/Slider/DateTimeInput）——V2。
- localStorage / 服务端 UI 状态持久化（刷新恢复）——V2。
- 按消息来源启用工具（只为 WebUI 来源的会话注入 `a2ui` 工具以省 token）——V2，且仅在观察到误触发时实施。
- 实验性推理格式（Atom/Express）以提升 token 效率——V2 评估。
- 超出基础子集的自定义 nanobot 专属 catalog 组件。
- 在非 WebUI 通道（Telegram/Discord 等）渲染 A2UI（超出文本降级范围）。
- 对 WebSocket 协议、通道基类或 agent loop 消息流的任何改动。

## 补充说明

- 可行性与全部决策已记录在 `docs/a2ui-integration.md`（同时镜像在作者的 Obsidian vault 中）——查阅该文件可获取完整决策记录与已核实的源码事实。
- `_agent_ui` / `AgentUIBlob` 扩展点已存在且目前未被任何通道使用；本特性激活它而无需协议改动。
- A2UI 尚处早期阶段（v0.9.x 稳定系列，v1.0 为 RC）——接口面集中在两个薄点（工具 + 自研渲染层），协议升级时影响可控。
- 安全姿态：A2UI 是声明式数据而非可执行代码；只渲染白名单 catalog 组件；`Image` 的 URL 需校验；将 agent 输出视为不可信输入。
