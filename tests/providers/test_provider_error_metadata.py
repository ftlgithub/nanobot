from types import SimpleNamespace

import pytest

from nanobot.providers.anthropic_provider import AnthropicProvider
from nanobot.providers.base import ERROR_KIND_CONTEXT_OVERFLOW, LLMProvider, LLMResponse
from nanobot.providers.openai_compat_provider import OpenAICompatProvider
from nanobot.providers.registry import find_by_name


def _fake_response(
    *,
    status_code: int,
    headers: dict[str, str] | None = None,
    text: str = "",
) -> SimpleNamespace:
    return SimpleNamespace(
        status_code=status_code,
        headers=headers or {},
        text=text,
    )


def test_openai_handle_error_extracts_structured_metadata() -> None:
    class FakeStatusError(Exception):
        pass

    err = FakeStatusError("boom")
    err.status_code = 409
    err.response = _fake_response(
        status_code=409,
        headers={"retry-after-ms": "250", "x-should-retry": "false"},
        text='{"error":{"type":"rate_limit_exceeded","code":"rate_limit_exceeded"}}',
    )
    err.body = {"error": {"type": "rate_limit_exceeded", "code": "rate_limit_exceeded"}}

    response = OpenAICompatProvider._handle_error(err)

    assert response.finish_reason == "error"
    assert response.error_status_code == 409
    assert response.error_type == "rate_limit_exceeded"
    assert response.error_code == "rate_limit_exceeded"
    assert response.error_retry_after_s == 0.25
    assert response.error_should_retry is False


def test_openai_handle_error_marks_timeout_kind() -> None:
    class FakeTimeoutError(Exception):
        pass

    response = OpenAICompatProvider._handle_error(FakeTimeoutError("timeout"))

    assert response.finish_reason == "error"
    assert response.error_kind == "timeout"


@pytest.mark.parametrize(
    ("provider_name", "message"),
    [
        (
            "ollama",
            "the prompt is longer than the context length currently available to the model",
        ),
        (
            "vllm",
            "This model's maximum context length is 8192 tokens. However, you requested 9000.",
        ),
    ],
)
def test_local_openai_provider_marks_known_context_overflow(
    provider_name: str,
    message: str,
) -> None:
    class FakeStatusError(Exception):
        pass

    err = FakeStatusError(message)
    err.status_code = 400
    err.body = {"error": {"message": message, "type": "BadRequestError", "code": 400}}

    response = OpenAICompatProvider._handle_error(
        err,
        spec=find_by_name(provider_name),
    )

    assert response.error_kind == ERROR_KIND_CONTEXT_OVERFLOW
    assert response.is_context_overflow_error


def test_local_openai_provider_does_not_guess_context_overflow_from_other_400() -> None:
    class FakeStatusError(Exception):
        pass

    err = FakeStatusError("model requires more system memory")
    err.status_code = 400
    err.body = {"error": {"message": str(err)}}

    response = OpenAICompatProvider._handle_error(err, spec=find_by_name("ollama"))

    assert response.error_kind is None
    assert not response.is_context_overflow_error


def test_anthropic_handle_error_extracts_structured_metadata() -> None:
    class FakeStatusError(Exception):
        pass

    err = FakeStatusError("boom")
    err.status_code = 408
    err.response = _fake_response(
        status_code=408,
        headers={"retry-after": "1.5", "x-should-retry": "true"},
    )
    err.body = {"type": "error", "error": {"type": "rate_limit_error"}}

    response = AnthropicProvider._handle_error(err)

    assert response.finish_reason == "error"
    assert response.error_status_code == 408
    assert response.error_type == "rate_limit_error"
    assert response.error_retry_after_s == 1.5
    assert response.error_should_retry is True


def test_anthropic_handle_error_marks_connection_kind() -> None:
    class FakeConnectionError(Exception):
        pass

    response = AnthropicProvider._handle_error(FakeConnectionError("connection"))

    assert response.finish_reason == "error"
    assert response.error_kind == "connection"


@pytest.mark.parametrize("expected, kwargs", [
    (True, {"error_status_code": 402}),  # HTTP 402
    (True, {"error_type": "insufficient_quota"}),  # billing token
    (True, {"content": "429 You exceeded your current quota"}),  # text marker
    (False, {"error_status_code": 429, "error_type": "rate_limit_exceeded"}),  # plain rate limit
])
def test_is_arrearage_response(expected: bool, kwargs: dict) -> None:
    response = LLMResponse(finish_reason="error", **{"content": "boom", **kwargs})
    assert LLMProvider.is_arrearage_response(response) is expected
