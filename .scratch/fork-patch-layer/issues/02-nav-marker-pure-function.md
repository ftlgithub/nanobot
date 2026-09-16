# 02 — 抽离 NAV 标记解析为纯函数 `parse_nav_marker()`

**What to build:** `<!--NAV:{json}-->` 标记的解析逻辑从 `loop.py` 的两处内联代码中消失，统一由 `nanobot/fork/navigation.py` 的 `parse_nav_marker()` 纯函数提供。`loop.py` 只保留 1 行调用，且行为与之前逐位一致（流式路径与持久化路径都正确剥离标记并提取 dict）。

**Blocked by:** 01 — 建立 `nanobot/fork/` 包骨架 + git rerere 配置

**Status:** ready-for-agent

- [ ] `nanobot/fork/navigation.py` 定义 `parse_nav_marker(text: str) -> tuple[dict | None, str]`：找到 `<!--NAV:{json}-->` 则返回 `(json_dict, 剥离后的文本)`；无标记返回 `(None, 原文)`；畸形 JSON 返回 `(None, 原文)`
- [ ] `loop.py` 流式路径（原 ~1251-1268 行）替换为调用 `parse_nav_marker(stream_content)`，后续 `if _nav_d:` 发布逻辑保留
- [ ] `loop.py` 持久化路径（原 ~1790-1796 行）替换为调用 `parse_nav_marker(final_content)`，`meta["_navigation"]` 注入保留
- [ ] `tests/fork/test_navigation.py` 新增单测：含标记/无标记/畸形 JSON 三种输入，断言 `(nav_dict, cleaned_text)` 输出
- [ ] `python -m pytest tests/fork/` 通过
- [ ] ruff 对改动文件无错误
- [ ] 回归：`tests/agent/test_loop_runner_integration.py` 仍通过（NAV 相关行为不变）