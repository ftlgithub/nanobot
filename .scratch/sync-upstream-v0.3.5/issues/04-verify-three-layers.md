# 04 — 三层验证（自动化 + 运行时 + 扩展端到端）

**What to build:** v0.3.5 升级后的完整验证，确认零回归：自动化测试通过、fork 4 大特性端到端行为不变、Chrome 扩展全功能正常。

**Blocked by:** 03 — 处理 v0.3.5 破坏性变更

**Status:** ready-for-agent

**自动化层：**
- [ ] `pytest tests/` 失败集 ≤ 基线（已知：test_dream、tui_launcher + 可能的 mcp/web_fetch 网络波动），**无新增失败**
- [ ] `tests/fork/` + `tests/channels/test_fork_navigation_dispatch.py` 全过（补丁层纯函数）
- [ ] `tests/agent/test_loop_runner_integration.py` 全过（错误掩蔽断言）
- [ ] `ruff check nanobot/` 通过
- [ ] WebUI `bun run test` + `bun run build` 通过

**运行时层（复用既有端到端脚本模式）：**
- [ ] CORS：`curl -H "Origin: ..." /webui/bootstrap` → `Access-Control-Allow-Origin: *`
- [ ] 用户映射：`new_chat` + 发消息 → `user_session_map.json` 有关联 → 删除 → 清理
- [ ] 错误掩蔽：`test_streamed_flag_not_set_on_llm_error` 通过
- [ ] 导航分发：`tests/channels/test_fork_navigation_dispatch.py` 通过
- [ ] mutation 删除：`session.delete` → `webui_response {deleted: true}`

**扩展层（需手动）：**
- [ ] reload 扩展，会话列表/新建/删除/切换正常
- [ ] 消息收发 + 工具调用（dct-north-cli）正常
- [ ] DevTools 无 `webui_response` 不匹配告警、无 import 报错