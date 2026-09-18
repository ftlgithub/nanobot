# 01 — STT bundle 双平台

**What to build:** 离线可用的语音转文字包：whisper.cpp 预编译二进制（macOS arm64 + Linux x64）＋ `ggml-medium.bin`（1.5GB，在用档）＋指向本地 `:9090` 的转写配置＋PM2 启停；双平台各转写一段中文 clip 通过。

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [ ] macOS：whisper.cpp 二进制（与现运行 1.9.1 同款或兼容版）+ `ggml-medium.bin` + 以 `--port 9090 --inference-path /audio/transcriptions` 启动
- [ ] Linux：对应平台预编译二进制 + 同一模型文件（跨平台通用）
- [ ] `siliconflow.apiBase → http://localhost:9090` 配置落盘（沿用生产现行重定向，零代码改动）
- [ ] PM2 配置（与现有 `tts-server` 管理方式一致）
- [ ] macOS 实机 + Linux（docker `--platform linux/amd64`）各转写一段中文测试音频，返回中文文字
- [ ] 组包脚本 + sha256（`packaging/build-stt.sh` 或并入现有构建入口，产物 git-ignored）
