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
    ("provider_name", "api_base", "status_code", "message"),
    [
        pytest.param(
            "ollama",
            None,
            400,
            "the prompt is longer than the context length currently available to the model; "
            "shorten the prompt, adjust the context length in settings",
            id="ollama-completion",
        ),
        pytest.param(
            "ollama",
            None,
            400,
            "the input length exceeds the context length",
            id="ollama-embedding",
        ),
        pytest.param(
            "vllm",
            None,
            400,
            "This model's maximum context length is 8192 tokens. However, you requested 9000.",
            id="vllm",
        ),
        pytest.param(
            "lm_studio",
            None,
            400,
            "Trying to keep the first 111490 tokens when context the overflows. However, the "
            "model is loaded with context length of only 32768 tokens, which is not enough.",
            id="lm-studio",
        ),
        pytest.param(
            "lm_studio",
            None,
            400,
            "Context size has been exceeded.",
            id="lm-studio-context-size",
        ),
        pytest.param(
            "atomic_chat",
            None,
            500,
            "the request exceeds the available context size. Try increasing context size or "
            "enable context shift",
            id="atomic-chat-llama-cpp",
        ),
        pytest.param(
            "atomic_chat",
            None,
            500,
            "Context size exceeded: requested 9000 tokens but the model only supports 8192.",
            id="atomic-chat-mlx",
        ),
        pytest.param(
            "atomic_chat",
            None,
            503,
            "context window overflow",
            id="atomic-chat-503",
        ),
        pytest.param(
            "ovms",
            None,
            400,
            "Input length exceeds pipeline capabilities: 9000 > 8192",
            id="ovms-continuous-batching",
        ),
        pytest.param(
            "ovms",
            None,
            400,
            "Input length exceeds the maximum allowed length",
            id="ovms-legacy",
        ),
        pytest.param(
            "custom",
            "http://localhost:11434/v1",
            400,
            "This model's maximum context length is 8192 tokens. However, you requested 9000.",
            id="custom-local-vllm",
        ),
    ],
)
def test_local_openai_provider_marks_known_context_overflow(
    provider_name: str,
    api_base: str | None,
    status_code: int,
    message: str,
) -> None:
    class FakeStatusError(Exception):
        pass

    err = FakeStatusError(message)
    err.status_code = status_code
    err.body = {
        "error": {
            "message": message,
            "type": "BadRequestError" if status_code < 500 else "server_error",
            "code": status_code,
        }
    }

    response = OpenAICompatProvider._handle_error(
        err,
        spec=find_by_name(provider_name),
        api_base=api_base,
    )

    assert response.error_kind == ERROR_KIND_CONTEXT_OVERFLOW
    assert response.is_context_overflow_error


@pytest.mark.parametrize(
    ("provider_name", "api_base", "status_code", "message"),
    [
        ("ollama", None, 400, "model requires more system memory"),
        ("atomic_chat", None, 500, "backend temporarily unavailable"),
        (
            "custom",
            "https://api.example.com/v1",
            400,
            "This model's maximum context length is 8192 tokens. However, you requested 9000.",
        ),
    ],
)
def test_openai_provider_does_not_guess_context_overflow_from_unrelated_errors(
    provider_name: str,
    api_base: str | None,
    status_code: int,
    message: str,
) -> None:
    class FakeStatusError(Exception):
        pass

    err = FakeStatusError(message)
    err.status_code = status_code
    err.body = {"error": {"message": str(err)}}

    response = OpenAICompatProvider._handle_error(
        err,
        spec=find_by_name(provider_name),
        api_base=api_base,
    )

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
