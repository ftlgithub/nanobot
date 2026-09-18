# 04 — nanobot 端到端 + 发版记录

**What to build:** 双包与 nanobot 联调通过的最终验收结论与发版记录。

**Blocked by:** 01 — STT bundle 双平台；03 — TTS Linux bundle

**Status:** ready-for-agent

- [ ] 语音消息 → 文字：发一段中文语音，收到正确转写（经 nanobot 转写配置链路，非直调 whisper）
- [ ] 文字 → TTS 播放：经扩展 TTS 调用链路播出可听音频
- [ ] 双平台覆盖：macOS 实机 + Linux（STT 必验；TTS 按目标机类型验对应后端）
- [ ] 发版记录：双包包名/大小/sha256/模型版本与来源/验证证据/已知限制（并入 `packaging/RELEASES*.md` 或新增语音章节）
- [ ] 已知限制如实记录：Linux TTS 需算力机；模型总大小；与主包/extras 包的版本配套关系