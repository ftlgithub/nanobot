# 02 — TTS macOS bundle

**What to build:** macOS 可用的离线语音合成包：现有 FastAPI 服务源码 + 重建的 standalone 运行环境 + Qwen3-TTS MLX 模型（2.5GB）+ PM2；POST `/v1/audio/speech` 返回可播放音频。

**Blocked by:** None — 与 01 可并行

**Status:** ready-for-agent

- [ ] 服务源码取自 `chrome-extension/tts-server/` 现状（含 `main.py` + helper 模块）
- [ ] 运行环境重建为 standalone Python + wheels（conda 1.7GB 不可直接搬；与主包同款做法）
- [ ] 模型：`mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-6bit`（2.5GB，已在 HF 缓存）
- [ ] PM2 配置（沿用现有 `tts-server` 管理方式）
- [ ] 本机验证：POST `/v1/audio/speech` 返回可播放音频（时长/采样率正常，非空文件）
- [ ] 组包脚本 + sha256；包内附 `BUILD-INFO.txt`（来源 commit/日期）
