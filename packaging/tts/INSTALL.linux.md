# nanobot TTS 离线包 — 安装说明（Linux x64）

内容：FastAPI 语音合成服务（Qwen3-TTS）+ 独立 Python 运行环境 + 原版模型权重 + PM2 配置。
本包为 **Linux x86_64** 专用（含原版 bf16 权重，约 3.5GB）；macOS 包另见。

## 目录结构

```
nanobot-tts-linux-x64-v0.3.5/
├── python/            # 独立 Python（含全部依赖 wheel 已装好，开箱即用）
├── service/           # FastAPI 服务源码（main.py + helper）
├── models/            # 原版模型目录（含 Qwen3-TTS-12Hz-1.7B-CustomVoice）
├── ecosystem.tts.config.js
├── 安装说明.md        # 本文件
└── BUILD-INFO.txt
```

## 安装

```bash
tar -xzf nanobot-tts-linux-x64-v0.3.5.tar.gz -C /opt/

# PM2 常驻（推荐，与现有 tts-server 管理方式一致）
cd /opt/nanobot-tts-linux-x64-v0.3.5
pm2 start ecosystem.tts.config.js

# 或前台验证
./python/bin/python -m uvicorn main:app --host 127.0.0.1 --port 8081 --app-dir service
```

服务监听 `http://127.0.0.1:8081`，扩展直连（`/v1/audio/speech`），不经过 nanobot。

## 验证

```bash
curl -s -X POST http://127.0.0.1:8081/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"input": "测试", "stream": true, "language": "zh"}' -o /tmp/t.wav
# 返回 base64 WAV；解码后应为 16kHz 可播放音频（>1s）
```

再经扩展：点 TTS 播放，应听到合成语音。

## 已知限制

- 仅 Linux x86_64（含 faster-qwen3-tts 后端）；macOS 包使用 MLX 后端（另包）。
- 需要 NVIDIA GPU（torch CUDA 图路径；纯 CPU 目标机不在本包支持范围）。
- 模型约 3.5GB bf16，整包约 8GB；磁盘需预留。
- 需要 glibc>=2.28（torch 2.14 manylinux wheels）。
- `HF_HUB_OFFLINE=1` 已预设：服务永不联网拉模型，缺模型会直接报错而非静默下载。
