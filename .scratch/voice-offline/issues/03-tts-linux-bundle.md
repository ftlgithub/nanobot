# 03 — TTS Linux bundle

**What to build:** Linux 算力服务器可用的离线语音合成包：同引擎 `faster-qwen3-tts` 后端（同音色，不换引擎）+ 原版权重 + PM2；合成通过。

**Blocked by:** 02 — TTS macOS bundle（复用环境重建与验证模式）

**Status:** ready-for-agent

- [ ] 补 `faster-qwen3-tts` 包（现环境未装；`Qwen3TTSHandler` 非 darwin 自动走该后端）
- [ ] 模型：原版 `Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice`（约 3.5GB bf16，下载时确认实际大小）
- [ ] 运行环境：standalone Python + wheels（含 torch，按目标机 CPU/CUDA 选型；用户已确认目标为有算力服务器）
- [ ] 后端切换验证：同 prompt 在 mac（MLX）与 Linux（faster）各合成一次，主观确认音色一致
- [ ] PM2 配置 + 组包脚本 + sha256；包内附 `BUILD-INFO.txt`
