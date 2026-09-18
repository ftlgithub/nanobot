# nanobot TTS 离线包 — 安装说明

内容：FastAPI 语音合成服务（Qwen3-TTS）+ 独立 Python 运行环境 + 模型权重 + PM2 配置。
本包为 **macOS arm64** 专用（含 MLX 版模型）；Linux 包另见。

## 目录结构

```
nanobot-tts-macos-arm64-v0.3.5/
├── python/            # 独立 Python（含全部依赖 wheel 已装好，开箱即用）
├── service/           # FastAPI 服务源码（main.py + helper）
├── models/            # HF 模型缓存目录结构（含 Qwen3-TTS MLX 版 2.5GB）
├── ecosystem.tts.config.js
├── INSTALL.md         # 本文件
└── BUILD-INFO.txt
```

## 安装

```bash
tar -xzf nanobot-tts-macos-arm64-v0.3.5.tar.gz -C /opt/

# PM2 常驻（推荐，与现有 tts-server 管理方式一致）
cd /opt/nanobot-tts-macos-arm64-v0.3.5
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

- 仅 macOS arm64（含 MLX）；Linux 需 `faster-qwen3-tts` 后端 + 原版权重（另包）。
- 模型 2.5GB，整包约 4GB；磁盘需预留。
- `HF_HUB_OFFLINE=1` 已预设：服务永不联网拉模型，缺模型会直接报错而非静默下载。
