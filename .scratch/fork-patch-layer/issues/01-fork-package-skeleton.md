# 01 — 建立 `nanobot/fork/` 包骨架 + git rerere 配置

**What to build:** fork 的本地修改开始有统一的"家"——`nanobot/fork/` 包可被 `import nanobot.fork` 且不报错；`git rerere` 已启用以自动复用历史冲突解决方案。这是后续所有抽离工作的地基。

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [ ] 创建 `nanobot/fork/__init__.py`，导出占位公共 API（`parse_nav_marker`、`mask_llm_error` 先声明为待实现占位）
- [ ] 创建空模块 `nanobot/fork/navigation.py`、`llm_error.py`、`cors.py`、`user_session.py`（可先空文件或 docstring）
- [ ] `git config rerere.enabled true` 已生效（`git config rerere.enabled` 返回 true）
- [ ] `python -c "import nanobot.fork"` 无报错
- [ ] ruff 对 `nanobot/fork/` 无错误