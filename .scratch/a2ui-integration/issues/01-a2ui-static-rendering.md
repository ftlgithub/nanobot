# 01 — A2UI 静态渲染端到端（tracer bullet）

**要构建什么：** 打通 A2UI 全链路最小闭环：agent 调用 `a2ui` 工具提交一个 `createSurface` + 组件列表的 A2UI v0.9 payload，payload 经目录 schema 校验（非法则返回结构化纠错错误给 LLM，不发射），合法则写入 outbound message 的 `_agent_ui` 元数据（`kind: "a2ui"`，`data` 为消息数组），经 WebSocket 通道透传到 WebUI；WebUI 侧接入 `@a2ui/web_core` 的 `MessageProcessor`，自研 `A2UISurface` 组件把 surface 渲染为可交互界面。本票只要求**静态展示**（渲染出来即可，不要求交互回传、不要求增量更新）。V1 实现 6 个组件：Row、Column、Text、Image、Button、TextField，通过 `Catalog` 注册、zod schema 声明。

**阻塞于：** 无，可立即开工。

**状态：** ready-for-agent

- [ ] `a2ui` 工具经工具自动发现注册，LLM 可通过工具调用提交 A2UI v0.9 消息数组（`createSurface`/`updateComponents`/`updateDataModel`/`deleteSurface`）
- [ ] 合法 payload → 工具调用成功后，outbound message 的 `_agent_ui` 元数据被填充为 `{"kind": "a2ui", "data": [...]}`，且 `content` 保留可读文本
- [ ] 非法 payload（缺组件 id、未知组件类型、schema 违规）→ 工具返回纠错错误，`_agent_ui` 不被写入
- [ ] 后端依赖 `a2ui-core` 以可选 extra 提供（默认不装）；`a2ui-agent-sdk` 未被引入
- [ ] WebUI 新增 `@a2ui/web_core` 依赖（不引入 `@a2ui/react`，React 保持 18）
- [ ] 收到 `agent_ui.kind === "a2ui"` 的 message 帧 → `MessageProcessor` 处理 → surface 出现在渲染输出中
- [ ] `A2UISurface` 能渲染 6 个 V1 组件（Row/Column/Text/Image/Button/TextField），Image 的 URL 经过校验
- [ ] 非 WebUI 通道（如 Telegram）收到含 A2UI 的消息时行为不变，仅显示 `content` 文本
