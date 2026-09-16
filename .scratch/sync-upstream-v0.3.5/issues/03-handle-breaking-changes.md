# 03 — 处理 v0.3.5 破坏性变更（会话存储迁移 + 入口点 + /health 语义）

**What to build:** v0.3.5 的破坏性变更在 fork 环境中正确处理：会话存储自动迁移且旧会话保留、网关启动命令不受 TUI 默认入口影响、`/health` 新语义被扩展/监控接受。

**Blocked by:** 02 — rebase 并解决全部冲突

**Status:** done

- [ ] 重启网关后，会话存储自动迁移到 `sessions/<workspace-id>/`，**旧会话内容保留**（列表可见、历史可加载）
- [ ] 若迁移未自动发生：手动执行迁移或确认原因；降级预案 `nanobot sessions restore-workspace` 已了解
- [ ] `nanobot gateway --foreground --port 18790 ...` 启动命令正常（v0.3.5 裸 `nanobot` 进 TUI，但 `gateway` 子命令不受影响）
- [ ] `~/.nanobot/config.json` 无废弃字段（`failOnToolError`、`NANOBOT_LLM_TIMEOUT_S`）；若有则按 v0.3.5 语义处理
- [ ] `/health` 返回语义符合 v0.3.5（WS 频道未运行返回 503）；扩展/监控无对 200 的硬依赖
- [ ] Email 频道未启用（无需 `trustedAuthservIds`）；若启用需按文档补齐
- [ ] 并发/超时新配置（`NANOBOT_MAX_CONCURRENT_REQUESTS` 默认无限制、`NANOBOT_STREAM_IDLE_TIMEOUT_S`）与 fork 期望一致