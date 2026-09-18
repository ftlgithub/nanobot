---
labels: [ready-for-agent]
---

# Spec: 语音服务离线包（STT + TTS 独立分包）

## Problem Statement

离线机上语音链路不可用：STT（语音转文字）当前走云端（`transcription.provider: siliconflow`），TTS（文字转语音）依赖本机 conda 环境与 HuggingFace 模型缓存，任一环节缺失即失败。主包与 extras 包均不含语音运行时，用户需要开箱即用的离线语音能力。

## Solution

交付**两个独立离线包**：STT 包（whisper.cpp 预编译二进制 + ggml-medium 模型 + 启动配置）与 TTS 包（FastAPI 服务源码 + 运行环境 + 模型权重 + PM2 配置）。STT 通过既有配置重定向接入（零代码改动）；TTS 沿用现有独立服务架构（扩展直连，不经 nanobot）。

## User Stories

1. As a 运维工程师, I want to 在无网 Linux 机上解压装好 STT, so that 语音转文字可用。
2. As a 运维工程师, I want to 在 macOS 上解压装好 TTS, so that 扩展的语音播报可用。
3. As a 运维工程师, I want to 在 Linux 算力服务器上装好 TTS, so that 同样的音色在 Linux 可用。
4. As a 运维工程师, I want to 用 PM2 启停两个服务（与现状一致）, so that 无需学新运维方式。
5. As a 终端用户, I want to 发语音消息后收到中文转写文字, so that 语音输入可用。
6. As a 终端用户, I want to 点 TTS 播放后听到合成语音, so that 语音播报可用。
7. As a fork maintainer, I want to STT/TTS 分开版本演进, so that 模型更新不互相牵连。
8. As a fork maintainer, I want to 包内容可追溯（来源/版本/sha）, so that 出问题能定位。

## Implementation Decisions

- **STT 方案**：whisper.cpp 预编译二进制（与 macOS 现用同款，Linux 取对应构建）+ `ggml-medium.bin`（1.5GB，在用档）。
- **STT 接入**：零代码改动——沿用既有 `siliconflow.apiBase → http://localhost:9090` 重定向（OpenAI 兼容 `/audio/transcriptions`）；安装时写配置即可。
- **TTS macOS 方案**：沿用现有 FastAPI 服务源码（`chrome-extension/tts-server/`）+ Qwen3-TTS MLX 版（`mlx-community/...-6bit`，2.5GB）+ 重建的 standalone 运行环境（conda 1.7GB 不可直接搬）。
- **TTS Linux 方案**：同引擎 `faster-qwen3-tts` 后端（`Qwen3TTSHandler` 已内置跨平台分支，darwin 走 MLX、其他走 torch），配原版权重（`Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice`，约 3.5GB，下载时确认）；需补 `faster-qwen3-tts` 包（现环境未装）。
- **包结构**：STT、TTS 各自独立 tarball（体量均 GB 级，互相独立，TTS 可能单独上 GPU 机）。
- **服务管理**：沿用 PM2（与现状一致）；install 脚本只装文件，不管进程。
- **技术说明**：TTS 独立于 nanobot（扩展直连 `:8081`）；STT 经 nanobot transcription 配置接入；两者都不改 fork 代码。

## Testing Decisions

- **测试 seam（单一最高层）**：运行中服务的对外接口——STT：POST 一段中文测试音频到转写端点 → 断言返回中文文字；TTS：POST `/v1/audio/speech` → 断言返回可播放音频；再加 nanobot 端到端（语音消息→文字，文字→TTS 播放）。
- **什么是好的测试**：只断言外部可观察行为（转写文本内容、音频可播放性、HTTP 状态），不测模型内部与权重文件清单。
- **将要测试的模块**：whisper-server 进程、TTS FastAPI 进程、nanobot 转写配置链路、扩展 TTS 调用链路。
- **测试的 prior art**：主包离线包的断网容器验证流程（`packaging/README.md`）；扩展 `voice/` 下既有 `tts-timeout.test.js` 等测试风格。

## Out of Scope

- 不换 TTS 引擎（Linux 也不换 Piper 等；坚持同引擎同音色）。
- 不做 STT large 系列模型（medium 已定；large-v3-turbo 另议）。
- 不把语音并入主包或 extras 包（体量与演进节奏不同）。
- 不改 fork 代码（STT 接入靠配置重定向；TTS 本来就独立）。
- 不验云端 ASR 回退路径（离线场景无意义）。
- ego-browser 打包问题不在此 spec（另有结论：独立浏览器应用，单独处理）。

## Further Notes

- 已查实体积：`~/.whisper/` 1.5GB（medium 1.5GB + tiny 77MB）；HF 缓存 6.4GB（含 Qwen3-TTS MLX 2.5GB）；tts-server conda env 1.7GB（含 torch/torchaudio/onnxruntime）。
- TTS 运行环境必须重建（conda 不可搬；走主包同款 standalone＋wheels）；`faster-qwen3-tts` 在 Linux 包里新增。
- STT 当前生产配置已是本地重定向（`siliconflow.apiBase=http://localhost:9090`），离线包只需复现该配置。
- 若后续 TTS 要上其他 Linux 发行版，注意 glibc 下限（沿用主包 manylinux2014 约定）。
