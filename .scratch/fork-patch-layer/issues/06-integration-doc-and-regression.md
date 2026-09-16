# 06 — `docs/fork-integration.md` 调用点清单 + 全量回归

**What to build:** 所有 fork 调用点有一份权威清单文档，rebase 冲突解决变为"照单核对"；全量测试验证重构行为保持（失败集与基线一致）。

**Blocked by:** 02 — 抽离 NAV 标记解析为纯函数 · 03 — 抽离 LLM 错误掩蔽为纯函数 · 04 — 用户映射统一出口 + 锚点 · 05 — CORS helper 抽离 + 锚点

**Status:** ready-for-agent

- [ ] `docs/fork-integration.md` 建表：hook id / 文件 / 锚点字符串 / 目的 / rebase 检查项，覆盖全部 `# FORK-HOOK` 锚点（`fork-nav-stream`、`fork-nav-persist`、`fork-err-mask`、`fork-cors-*`、`fork-user-map-*`、`fork-nav-send`）
- [ ] `git grep "FORK-HOOK"` 结果与文档清单一一对应，无遗漏无多余
- [ ] 全量 `pytest`：失败集 = 基线 9 个（mcp/web_fetch 网络、test_dream、tui_launcher），无新增失败
- [ ] `ruff check nanobot/` 通过
- [ ] WebUI `bun run test` + `bun run build` 通过
- [ ] 端到端抽查：navigation 事件（`<!--NAV:-->` → WS `navigation`）+ CORS 头 + 用户映射三项行为与重构前一致