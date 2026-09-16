# 05 — 干净环境验收 + 发版记录

**What to build:** 双平台离线包的最终验收结论与发版记录：两个 tarball 在各自干净环境一次装通、全链路通过，关键证据留档。

**Blocked by:** 02 — macOS arm64 tarball 全链路；03 — Linux x64 tarball 全链路

**Status:** done

- [ ] macOS：干净用户下 `install.sh` 退出码 0；bootstrap→建会话→发消息→mutation 删除→health 全过；导入横扫通过
- [ ] Linux：docker 干净容器内同上全链路通过
- [ ] fork 特性抽查：CORS 头、用户映射、错误掩蔽文案与线上行为一致
- [ ] 发版记录：tarball 文件名含版本号+平台+日期；sha256 留档；已知限制说明（无第三方 CLI App、无 macOS x64/Windows/arm64 Linux）