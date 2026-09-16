"""Tests for fork LLM error masking."""

from __future__ import annotations

from nanobot.fork.llm_error import MASKED_ERROR_MESSAGE, mask_llm_error


def test_masks_raw_error_text() -> None:
    raw = 'Error: {"type": "rate_limit", "detail": "..."}'
    assert mask_llm_error(raw) == MASKED_ERROR_MESSAGE


def test_masks_empty_or_none_input() -> None:
    assert mask_llm_error(None) == MASKED_ERROR_MESSAGE
    assert mask_llm_error("") == MASKED_ERROR_MESSAGE


def test_masks_non_string_input() -> None:
    assert mask_llm_error(12345) == MASKED_ERROR_MESSAGE


def test_mask_message_is_fixed_unchanged() -> None:
    assert MASKED_ERROR_MESSAGE == "模型服务暂时不可用，请稍后重试。"
