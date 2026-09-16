# 05 — 推送 + 收尾（origin/gitlab + 清理备份分支）

**What to build:** 升级完成的最终状态：fork 的 v0.3.5 基线推送到远端，备份分支清理，升级记录留档。

**Blocked by:** 04 — 三层验证全部通过

**Status:** ready-for-agent

- [ ] 提交所有 rebase 冲突解决的改动（如有）
- [ ] `git push --force-with-lease origin main`（若 SSH 代理不通，记录待用户补推）
- [ ] `git push --force-with-lease gitlab main` 成功
- [ ] 删除 `backup-main-before-v035` 备份分支（确认升级稳定后）
- [ ] 更新 `docs/changes-since-origin-main.md` 或等效记录（若项目维护该文件）
- [ ] 升级记录存档：`.scratch/sync-upstream-v0.3.5/` 的 spec + tickets 标记完成状态