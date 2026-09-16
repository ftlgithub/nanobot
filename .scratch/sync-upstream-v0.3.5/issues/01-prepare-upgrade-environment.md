# 01 — 准备升级环境（备份 + 拉取 v0.3.5 + 依赖同步）

**What to build:** 升级前的环境就绪状态：当前 `main` 指针有备份可回滚，v0.3.5 代码可访问，运行环境依赖与 v0.3.5 对齐。此阶段不产生代码改动，只做环境准备。

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [ ] `git branch backup-main-before-v035` 已创建（指向 `3c37ddb2`）
- [ ] `git fetch upstream tag v0.3.5` 成功（HTTPS 拉取，SSH 可能被代理阻断）
- [ ] 确认 v0.3.5 与当前 main 的差距（`git rev-list --count HEAD..v0.3.5`）
- [ ] conda env `nanobot-312` 执行 `pip install -e .`（若 v0.3.5 引入新依赖）
- [ ] `nanobot --version` 或等效命令可运行
- [ ] 网关当前运行状态已知（PID/端口），升级期间可重启