# 04 — TUI 双平台预置

**What to build:** `nanobot-tui-darwin-arm64.zip` 与 `nanobot-tui-linux-x64.zip` 两个原生二进制落盘到 `nanobot/tui/bin/`（TUI 启动优先用包内路径），02/03 组包时直接引用。

**Blocked by:** 01 — 冻结依赖 + 定义瘦生产环境

**Status:** done

- [ ] 从上游 release（与 fork 基线对应版本）下载 darwin-arm64 与 linux-x64 的 `nanobot-tui-*.zip`
- [ ] 校验 sha256（对照 release 附带的 `.sha256` 文件）
- [ ] 解压布局符合 `tui_launcher.py` 的 `nanobot/tui/bin/<asset>` 查找路径
- [ ] 本机验证：断网条件下裸 `nanobot` 能进 TUI（不触发 GitHub 下载）