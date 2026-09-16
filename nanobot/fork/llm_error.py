"""Fork: LLM error masking helpers."""

from __future__ import annotations

from typing import Any

MASKED_ERROR_MESSAGE = "模型服务暂时不可用，请稍后重试。"


def mask_llm_error(final_content: Any) -> str:
    """Mask raw LLM error text with a user-friendly message.

    Raw model/API error output (e.g. ``"Error: {...}"`` JSON) must never be
    echoed back to users; it is logged server-side only.
    """
    return MASKED_ERROR_MESSAGE
