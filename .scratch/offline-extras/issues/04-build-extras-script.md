# 04 — `build-extras.sh` + 发版记录

**What to build:** 一键产出 `nanobot-extras-<version>.tar.gz` 并记录 sha256，附包内安装说明与发版文档，风格与主包打包一致。

**Blocked by:** 03 — 安装器（`installer.py` + `install-extras.sh`）

**Status:** ready-for-agent

- [ ] `packaging/build-extras.sh`：组包（资产 + `installer.py` + `install-extras.sh` + 安装说明）→ tar → sha256，输出到 `packaging/build/extras/`
- [ ] 包内附 `安装说明.md`（中文，含：适用主包版本、安装命令、PATH 与重启提示、换 `--workspace` 需重跑的说明、已知限制）
- [ ] 前置校验：`packaging/extras/assets/` 缺项时拒绝打包；工作区脏时拒绝（与主包 build.sh 一致，`ALLOW_DIRTY=1` 可放行测试）
- [ ] `packaging/README.md` 与 `packaging/RELEASES.md`/`RELEASES.zh-CN.md` 增 extras 章节（包名/大小/sha256/源码 commit/验证证据）
- [ ] 产出 tarball 尺寸合理（预期数 MB 级，非百 MB）