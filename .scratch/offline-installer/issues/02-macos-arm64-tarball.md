# 02 — macOS arm64 tarball 全链路

**What to build:** macOS arm64 可用的离线安装 tarball：解压后一条命令装完，网关+WebUI 可跑，裸 `nanobot` 可进 TUI。

**Blocked by:** 01 — 冻结依赖 + 定义瘦生产环境；04 — TUI 双平台预置

**Status:** done

- [ ] 独立 Python（arm64）+ 按 lock 文件的 wheelhouse（`--no-index` 可装）
- [ ] WebUI 前端已预构建（`nanobot/web/dist` 随包）
- [ ] TUI darwin-arm64 二进制已预置 `nanobot/tui/bin/`（来自 04）
- [ ] `install.sh` 一键安装成功（退出码 0），目录自包含可搬迁
- [ ] 干净用户下验证：bootstrap→建会话→发消息→mutation 删除→health 全链路通过
- [ ] 导入横扫通过（全顶层模块 + channel/tool discover）