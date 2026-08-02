# 02 — A2UI 交互回传（action round-trip）

**要构建什么：** 用户在 WebUI 渲染出的 A2UI 界面上操作（点击 Button、在 TextField 输入后提交），产生 `{version, action: {name, context}}` 动作；WebUI 将其作为 inbound message 回传 agent——`metadata` 携带结构化 `a2ui_action` payload，`content` 携带人类可读摘要（如 `[a2ui] 用户点击了"提交预订"按钮，表单：日期=3月1日，人数=2`）。摘要进入会话历史与 LLM 上下文，LLM 据此响应（可再次调用 `a2ui` 工具更新界面）。本票让"点按钮 → agent 回复"的闭环工作。

**阻塞于：** 01 — A2UI 静态渲染端到端（需要先有渲染管线与 6 个组件才能产生交互）

**状态：** ready-for-agent

- [ ] Button 组件渲染出的可点击元素触发 action 回调，回调载荷形状为 `{version, action: {name, context}}`
- [ ] TextField 支持输入，提交时把输入值并入 action 的 `context`
- [ ] 动作以 inbound message 回传：`metadata["a2ui_action"]` 含结构化 payload，`content` 含可读摘要
- [ ] 摘要文本进入会话历史与 LLM 上下文，agent 能在下一轮据此响应
- [ ] 动作摘要对非 WebUI 通道同样可读（历史回放不依赖 UI）
- [ ] 前端测试：action 回调以预期形状触发；回传消息同时含结构化 payload 与摘要
