# 离线安装包发版记录

## v0.3.5（2026-09-16，fork main ＋ 离线打包）

源码版本：`0d4925e5`（`build: reject dirty worktree in build.sh; record source commit in releases`），构建自该提交的干净工作区。

> **哈希是「单次构建产物」的标识，不是「某 commit」的标识。** 同一 commit 重打磨
> 会产生不同 SHA-256（体积也会略有差异），因为应用 wheel 内嵌构建时间戳。下表只
> 标识某个具体产物；每次重打都必须重新验证并更新记录。

| 平台 | 安装包 | 大小 | SHA-256 |
|---|---|---|---|
| macOS arm64 | `nanobot-offline-macos-arm64-v0.3.5.tar.gz` | 86 MB | `5c2e3b0eed6cb14dbbc56d4369e0d2cd3cd76ceba2b43bdc95791dc71dab8004` |
| Linux x64（glibc 2.17+） | `nanobot-offline-linux-x64-v0.3.5.tar.gz` | 194 MB | `ba37cf50b1d7008f070c14ff802fdcbaf27493fb839272aea0b471a0e9c3f956` |

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
