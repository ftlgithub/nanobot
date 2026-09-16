# 04 — 用户映射统一出口（re-export）+ `# FORK-HOOK` 锚点

**What to build:** 用户会话映射的对外出口统一到 `nanobot/fork/user_session.py`（re-export 现有 `user_session_map` 单例），`inbound_commands.py` 与 `ws_http.py` 的 3 个调用点旁加上 `# FORK-HOOK` 锚点注释。行为不变：`new_chat` 关联用户、会话列表按用户过滤、删除会话时解除关联。

**Blocked by:** 01 — 建立 `nanobot/fork/` 包骨架 + git rerere 配置

**Status:** ready-for-agent

- [ ] `nanobot/fork/user_session.py` re-export `get_instance`（`from nanobot.webui.user_session_map import get_instance`），保持存储格式与单例语义不变
- [ ] `nanobot/fork/__init__.py` 导出 `get_user_map`（统一出口）
- [ ] `inbound_commands.py` 的 `associate` 调用点（原 ~308 行）旁加 `# FORK-HOOK: fork-user-map-associate — see docs/fork-integration.md`
- [ ] `ws_http.py` 的 `filter_sessions`（原 ~774 行）与 `dissociate`（原 ~972 行）调用点旁各加 `# FORK-HOOK` 锚点
- [ ] 现有 import 改为走 `nanobot.fork`（或保留旧 import 但确认 re-export 一致）
- [ ] 端到端验证：`new_chat` 后 `user_session_map.json` 出现关联；删除会话后关联清除（复用既有 WS mutation 脚本模式）
- [ ] ruff 无错误；`tests/channels/test_websocket_application_boundary.py` 仍通过