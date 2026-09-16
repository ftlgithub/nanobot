# 05 — CORS helper 抽离 + `# FORK-HOOK` 锚点

**What to build:** CORS 常量与响应头 helper 集中到 `nanobot/fork/cors.py`；`http_utils.py` 的 `cors_origin` 签名参数**保留**（不改变函数签名），`ws_http.py` 的 `CORS_ALLOW_ALL` 使用点旁加 `# FORK-HOOK` 锚点。行为不变：带 `Origin` 的请求仍返回 `Access-Control-Allow-Origin` 头，Chrome 扩展跨域访问正常。

**Blocked by:** 01 — 建立 `nanobot/fork/` 包骨架 + git rerere 配置

**Status:** ready-for-agent

- [ ] `nanobot/fork/cors.py` 定义 `CORS_ALLOW_ALL = "*"` 与 `cors_header(origin: str) -> tuple[str, str]` helper
- [ ] `http_utils.py` 的 `cors_origin` 逻辑保持原样（签名不动），如引用 `fork.cors` 常量则确认无行为差异
- [ ] `ws_http.py` 的 bootstrap 相关 `cors_origin=CORS_ALLOW_ALL` 使用点（原 ~619/621/630 行）旁加 `# FORK-HOOK: fork-cors-bootstrap` 等锚点
- [ ] 端到端验证：`curl -H "Origin: http://example.com" http://127.0.0.1:8765/webui/bootstrap` 返回 `Access-Control-Allow-Origin: *` 头
- [ ] ruff 无错误；`tests/webui/` 相关测试仍通过