from nanobot.utils.runtime import TOOL_ERROR_RECOVERY_HINT, with_tool_error_recovery_hint


def test_tool_error_recovery_hint_is_appended_exactly_once() -> None:
    error = "Error: tool failed"

    hinted = with_tool_error_recovery_hint(error)

    assert hinted == error + TOOL_ERROR_RECOVERY_HINT
    assert with_tool_error_recovery_hint(hinted) == hinted
