# 离线安装包发版记录

## v0.3.5（2026-09-16，fork main ＋ 离线打包）

源码版本：`84acc444`（`docs: packaging directory overview`）。
安装包构建自该提交的干净工作区；同提交重打的包除内嵌时间戳外内容一致。

| 平台 | 安装包 | 大小 | SHA-256 |
|---|---|---|---|
| macOS arm64 | `nanobot-offline-macos-arm64-v0.3.5.tar.gz` | 91 MB | `01c60555e480e5cff21e15562a4f5154aa515415c405b7c435fa81425c43d6ce` |
| Linux x64（glibc 2.17+） | `nanobot-offline-linux-x64-v0.3.5.tar.gz` | 203 MB | `05c60cfa75b64e20f67c42df3303f80c2f8780a7e7e4d92ec8c7a0f4573edd19` |

安装包位于 `packaging/build/<平台>/`（git-ignored 构建产物，不入库）。

### 包内容（每个平台包）

- 独立 Python 3.12（macOS 用 uv 管理版；Linux 用 python-build-standalone `20260901`）＋ `install.sh`（两步 `--no-index` 安装）
- 锁定版 wheelhouse（89 个 pin；Linux 侧 pillow 12.2.0／rapidfuzz 3.13.0／tiktoken 0.11.0 降级适配 manylinux2014，见 `packaging/locks/`）
- 预构建 WebUI 前端（随包的 `nanobot/web/dist`，与当前源码一致）
- 对应平台的 TUI 原生二进制（预置，避免运行时去 GitHub 下载）
- `requirements.txt`（install.sh 使用的平台锁拷贝）

### 验证结果（2026-09-16）

- macOS：全新解压＋干净 HOME 安装 → `nanobot v0.3.5`，模块正常；网关冒烟（bootstrap → 建会话 → 发消息 → mutation 删除 → health）通过。
- Linux：`ubuntu:22.04` amd64 容器、`--network none` 断网 → 安装成功；同样冒烟全链路通过（`deleted:true`，`health ok/running`）。
- 导入横扫：324 个模块通过；7 个失败均为已知可选 extra（aiohttp/api、matrix、slack、telegram、Windows 专属），符合预期。

### 已知限制

- 未预装第三方 CLI App（如 dct-north-cli；`entry_point` 为机器绝对路径，需独立方案，待服务端用例确认）。
- 暂无 macOS x64／Windows／Linux arm64 构建。
- Linux 锁与 macOS 有 3 处版本差异（见上），运行时 API 已验证兼容。
- macOS 打的 tar 包在 Linux 解压时会有 `LIBARCHIVE.xattr` 告警，无害，可忽略。

### 安装方法

```bash
tar -xzf nanobot-offline-<平台>-v0.3.5.tar.gz
bash nanobot-offline/install.sh ~/nanobot-offline   # 无需网络
export PATH="$HOME/nanobot-offline/bin:$PATH"
nanobot gateway   # 或 nanobot --help
```
