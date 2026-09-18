# STT 离线包 — 安装说明

内容：whisper.cpp `whisper-server`（macOS arm64 / Linux x64）＋ `ggml-medium.bin`（1.5GB）
＋ 各平台静态 ffmpeg（`--convert` 转码微信 mp3/m4a 必需）。macOS 为**单文件静态构建**
（Metal 已编入二进制）；Linux 另带 ggml 后端 `.so`。

## 目录结构

```
nanobot-stt-<platform>-v0.3.5.tar.gz
├── <platform>/                 # macos-arm64 或 linux-x64
│   ├── bin/whisper-server      # 服务二进制（macOS：静态链接、无外部依赖）
│   ├── bin/ffmpeg              # 静态 ffmpeg（--convert 用）
│   ├── lib/                    # 仅 Linux：版本化 .so（含 libgomp）；macOS 无此目录
│   └── start-whisper.sh        # 启动脚本（自动配好库路径/PATH）
├── ggml-medium.bin             # 模型（跨平台通用，1.5GB）
├── ecosystem.stt.config.js     # PM2 配置
└── INSTALL.md                  # 本文件
```

## 安装

```bash
tar -xzf nanobot-stt-<platform>-v0.3.5.tar.gz -C /opt/
cp ggml-medium.bin /opt/nanobot-stt/   # 或集中模型目录，二选一见下

# 直接启动（前台验证）
/opt/nanobot-stt/<platform>/start-whisper.sh /opt/nanobot-stt/ggml-medium.bin 9090 127.0.0.1

# PM2 常驻
BUNDLE_DIR=/opt/nanobot-stt/<platform> pm2 start ecosystem.stt.config.js
```

## 接入 nanobot

把转写配置指向本地服务（零代码改动，沿用生产现行做法）：

```json
// config.json → transcription 段（或 channels.transcriptionProvider 旧字段）
{ "provider": "siliconflow", "model": "whisper-1" }
// 对应 provider 条目：
{ "siliconflow": { "apiKey": "not-needed", "apiBase": "http://localhost:9090" } }
```

原理：whisper-server 暴露 OpenAI 兼容 `/audio/transcriptions`，
nanobot 以为在调 SiliconFlow，实际流量走本地。

## 验证

```bash
# 健康：服务启动日志出现模型加载完成，无 ffmpeg 缺失报错
# 转写：POST 一段中文 wav 到 http://127.0.0.1:9090/audio/transcriptions
# 应返回 {"text": "...中文..."}
# 再经 nanobot：发一条语音消息，收到中文转写文字
```

## 已知限制

- Linux 二进制在 glibc 2.17 环境编译（centos:7），最高用到 GLIBC 2.14，
  低于 2.17 下限要求——兼容。
- `--convert` 必须配 ffmpeg，本包已内置静态版；勿删 `bin/ffmpeg`。
- macOS 版为静态单文件构建，Metal 加速已编入二进制（无 `lib/`、无外部 dylib）；
  Linux 版为 CPU（OpenMP，包内自带 `libgomp`），GPU 服务器如需 CUDA 加速需另行构建。
- 模型只有 medium 档；要 tiny/large 另行下载 ggml 文件替换即可（同目录）。
