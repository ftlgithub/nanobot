# 03 — A2UI 增量更新（incremental updates）

**要构建什么：** 让 agent 能跨回合增量更新已存在的 A2UI surface，而不是每次整块重建。`agent_ui.data` 支持 A2UI 消息数组原样透传：一个回合可含 `createSurface → updateComponents → updateDataModel` 多步增量；后续回合可只发 `updateComponents`（改组件树局部）或 `updateDataModel`（改数据绑定值）。WebUI 侧 `MessageProcessor` 逐条处理消息，surface 状态在客户端持续累积，增量更新后 UI 局部变化而非整棵重建。本票让"上一回合的界面在下回合局部刷新"工作。

**阻塞于：** 01 — A2UI 静态渲染端到端（需要先有渲染管线与 surface 生命周期）

**状态：** ready-for-agent

- [ ] `agent_ui.data` 作为 A2UI 消息数组透传，多消息（含跨操作类型）原样到达 WebUI
- [ ] 同一回合内 `createSurface → updateComponents → updateDataModel` 顺序处理后 surface 最终状态正确
- [ ] 后续回合发送 `updateComponents` 或 `updateDataModel` 时，已存在的 surface 被更新而非重建
- [ ] `deleteSurface` 消息销毁对应 surface，WebUI 移除渲染
- [ ] 前端测试：增量 `updateComponents`/`updateDataModel` 后 UI 局部更新，不重新创建整个 surface
- [ ] 工具级测试：多消息数组在合法校验后被完整保留（不透传丢失）
