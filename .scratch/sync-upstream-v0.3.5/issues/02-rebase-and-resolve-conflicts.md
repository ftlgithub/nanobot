# 02 — rebase 10 个本地提交到 v0.3.5，解决全部冲突

**What to build:** fork 的 10 个本地提交重放到 v0.3.5 之上，所有冲突已解决，fork 特性（用户映射/CORS/导航/错误掩蔽）在 rebase 后仍完整存活。核心依据是 `docs/fork-integration.md` 的 hook 清单。

**Blocked by:** 01 — 准备升级环境

**Status:** done

- [ ] `git rebase v0.3.5` 开始，10 个提交逐个重放
- [ ] 每个冲突文件按 `docs/fork-integration.md` 核对锚点（`fork-nav-stream`/`fork-nav-persist`/`fork-err-mask`/`fork-nav-send`/`fork-nav-dispatch`/`fork-cors-*`/`fork-user-map-*`）
- [ ] `nanobot/fork/` 包在 rebase 中零冲突（上游不触碰）
- [ ] rebase 完成，无冲突残留（`git status` 干净）
- [ ] `git grep "FORK-HOOK:"` 结果与 `docs/fork-integration.md` 清单一一对应（14 个锚点 / 10 个唯一 hook id）
- [ ] `python -c "import nanobot.fork"` 无报错
- [ ] 所有 fork 逻辑文件（`nanobot/fork/*`）未被 rebase 修改（diff 为空）
- [ ] 若上游 v0.3.5 移除了某个锚点所在代码路径：决定该 fork 行为是否仍需保留，必要时在新位置重贴锚点