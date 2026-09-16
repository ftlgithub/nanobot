# 01 — 冻结依赖 + 定义瘦生产环境

**What to build:** 离线包的依赖基线：从已验证环境导出精确版本锁，外加一份瘦生产环境定义（仅运行时依赖），本机可复现装出，为双平台组包提供唯一输入。

**Blocked by:** None — can start immediately

**Status:** done

- [ ] 从已验证环境导出 `requirements.lock`（精确版本，含直接+传递依赖）
- [ ] 瘦环境定义文档化：仅 `pyproject` dependencies（无 dev/test），可一键复现安装
- [ ] 本机用 lock 文件重装验证：装完 `import nanobot` 与关键入口可用
- [ ] lock 文件纳入版本管理（后续打包含义一致、可重打）