# packaging/ — nanobot 离线安装包构建区

给无网机器用的自包含 tarball 在这里组装。构建机需联网，产物安装零网络。

## 目录结构

| 路径 | 说明 | 进 git？ |
|---|---|---|
| `build.sh` | 一键双平台构建脚本（`./packaging/build.sh [macos\|linux\|all]`） | ✅ |
| `install.sh` | 装机脚本模板，随 tarball 发布 | ✅ |
| `locks/` | 双平台依赖锁（`requirements-*.txt`）＋说明 | ✅ |
| `tui-binaries/README.md` | TUI 二进制来源＋sha256（manifest） | ✅ |
| `RELEASES.md` / `RELEASES.zh-CN.md` | 发版记录（包名/sha/验证/限制，中英） | ✅ |
| `INSTALL.zh-CN.md` | 用户侧安装使用文档（随 tarball 发布） | ✅ |
| `extras/` | **内部资产 extras 包**：`stage-assets.sh`、`installer.py`、`install-extras.sh`、`安装说明.md`、`README.md` | ✅ |
| `extras/assets/` | extras 内部资产实际内容（内网信息/凭据/内部 wheel） | ❌ **gitignored** |
| `build-extras.sh` | extras 组包（资产 + 安装器 + 说明 → tarball + sha256） | ✅ |
| `tts/` | **TTS 语音合成包输入**：双平台依赖锁、PM2 配置、`RELEASES.md`、`INSTALL.md`／`INSTALL.linux.md` | ✅ |
| `stt/` | **STT 语音转写包输入**：`start-whisper.sh`、PM2 配置、`RELEASES.md`、`INSTALL.md`、`README.md` | ✅ |
| `build-tts.sh` | TTS 组包（`./packaging/build-tts.sh [macos\|linux]`） | ✅ |
| `build-stt.sh` | STT 组包（`./packaging/build-stt.sh [macos\|linux\|all]`） | ✅ |
| `build/` | 构建输出（tarball、wheelhouse、解包目录） | ❌（GB 级，git-ignored） |
| `nanobot/tui/bin/`（仓库根下，非本目录） | TUI 二进制落盘处 | ❌（仅 `.gitkeep` 入库） |

> **主包 vs extras**：`build.sh` 出通用主包（`nanobot-offline-*`）；`build-extras.sh` 出**内部资产**
> extras 包（`nanobot-extras-*`，跨平台单包）。两者版本需配套；内部信息与凭据只在 extras 中。
> 详见 [`extras/README.md`](extras/README.md)。
>
> **语音包（独立演进，不进主包）**：`build-tts.sh` 出 `nanobot-tts-<平台>-*`；
> `build-stt.sh` 出 `nanobot-stt-<平台>-*`。体量 GB 级、可能单独上算力机，故与主包分开分发。

## 构建流程

**主包（通用，按平台）**

```
1. 前置校验：WebUI dist 新鲜、TUI zips 就位
2. 独立 Python（mac: uv 管理版；linux: python-build-standalone）
3. wheelhouse：按 locks/ 用 --platform 限定下载（Linux 限 manylinux2014）
4. 主包 wheel + TUI 解压 + install.sh + requirements.txt + 安装说明
5. tar + sha256 → packaging/build/<平台>/
```

**extras（内部资产，跨平台单包）**

```
1. packaging/extras/stage-assets.sh    # 从本机源收集资产（含清理凭据/产物校验）
2. packaging/build-extras.sh          # 前置校验 → 组包 → tar + sha256 + BUILD-INFO
   → packaging/build/extras/nanobot-extras-v<ver>.tar.gz
```

**语音包（STT/TTS，按平台）**

```
TTS — build-tts.sh
  1. 前置：扩展 tts-server 源码、对应平台依赖锁、模型权重（mac: MLX 6bit 缓存；linux: 原版权重）
  2. 独立 Python 3.11 + wheelhouse 离线装依赖 + service + 模型 + PM2 配置 + 安装说明
  3. tar + sha256 → packaging/build/tts/<平台>/
  注意：linux 分支必须在 Linux 容器内跑（staged Python 是 Linux 解释器，macOS 无法执行）

STT — build-stt.sh
  1. 前置：模型 ggml-medium.bin（sha256 门禁）、ffmpeg 缓存、cmake + Xcode CLT（mac）/ docker（linux）
  2. whisper.cpp v1.9.1 源码编译 → whisper-server + 启动脚本 + 模型 + PM2 配置 + 安装说明
  3. tar + sha256 → packaging/build/stt/
  注意：两平台均源码编译。macOS 静态链接 + Metal 编入二进制（单文件自包含，无 lib/）；
        Linux 在 centos:7 容器内编译（目标机 glibc ≥2.17 即可），可在 macOS 上跑
```

详见各阶段文档：`locks/README.md`（依赖策略）、`tui-binaries/README.md`
（二进制来源）、`extras/README.md`（extras 资产与安装器）、`RELEASES.md`（主包发版清单）、
`tts/RELEASES.md`、`stt/RELEASES.md`（语音包发版清单）。

## 验证

**主包**：干净环境安装（`install.sh` 退出码 0）＋全链路冒烟
（bootstrap → 建会话 → 发消息 → mutation 删除 → health）＋导入横扫。
macOS 用干净 HOME，Linux 用 docker 断网容器。历史验证记录见
`RELEASES.md`／`.scratch/offline-installer/issues/05-*`。

**extras**：断网环境装完主包 + extras 后，脚本退出码 0 且幂等、三个 CLI 可
`run_cli_app` 调起、6 个 skill 可见无重复、MCP 能启动列出 tools、
`installed.json` 无开发机绝对路径、主包冒烟仍通过。
见 `.scratch/offline-extras/spec.md`。

**STT**：macOS 实机 + Linux `centos:7` 容器各转写一段中文 clip 通过
（容器内 `ldd` 干净、目标机 glibc ≥2.17）。见 `stt/RELEASES.md`。

**TTS**：容器内已验证 service 编译、依赖 import 横扫、torch 后端接线、包内权重可解析。
`/v1/audio/speech` 合成冒烟**需 NVIDIA GPU 目标机**（torch 后端强制 CUDA；纯 CPU 目标机不在支持范围）。
见 `tts/RELEASES.md`。

## 后续可选项（已评估，暂缓）

| 项 | 现状 | 触发条件 |
|---|---|---|
| 可复现构建 | **不做**。`RELEASES.md` 里的哈希标识单次产物而非 commit（应用 wheel 内嵌构建时间戳，同 commit 重打磨哈希/体积会变）。分发校验用 `SHA256SUMS` 比对收到的那份文件即可，不依赖可复现。 | 需要对外分发、过供应链审计，或要求"重打必得同哈希"时 |
| `BUILD-INFO.txt` | **主包未加**（extras 包**已含**：source_commit/build_date/platform）。主包只拿 tarball 无法确定对应 commit（需配合 `RELEASES.md`）。 | 主包也需自描述来源时。约 20 行：记录 source_commit / build_date / lock 哈希 / app wheel 哈希 / TUI 哈希 |
