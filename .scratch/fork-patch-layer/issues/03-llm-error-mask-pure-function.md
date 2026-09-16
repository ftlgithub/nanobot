# 03 — 抽离 LLM 错误掩蔽为纯函数 `mask_llm_error()`

**What to build:** LLM 返回 error 时的错误文本掩蔽逻辑从 `loop.py` 内联代码中消失，由 `nanobot/fork/llm_error.py` 的 `mask_llm_error()` 纯函数提供。`loop.py` 只保留 1 行调用，用户看到"模型服务暂时不可用，请稍后重试。"的行为不变。

**Blocked by:** 01 — 建立 `nanobot/fork/` 包骨架 + git rerere 配置

**Status:** ready-for-agent

- [ ] `nanobot/fork/llm_error.py` 定义 `mask_llm_error(final_content: str | None) -> str | None`：始终返回固定文案 `"模型服务暂时不可用，请稍后重试。"`（当前掩蔽策略）
- [ ] `loop.py` 的 `result.final_content = "模型服务暂时不可用，请稍后重试。"`（原 ~1274 行）替换为 `result.final_content = mask_llm_error(result.final_content)`
- [ ] `tests/fork/test_llm_error.py` 新增单测：断言任意输入都返回固定文案
- [ ] `python -m pytest tests/fork/` 通过
- [ ] ruff 对改动文件无错误
- [ ] 回归：`tests/agent/test_loop_runner_integration.py` 仍通过（错误掩蔽断言兼容）