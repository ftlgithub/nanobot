"""Tests for fork NAV marker parsing."""

from __future__ import annotations

from nanobot.fork.navigation import parse_nav_marker


def test_no_marker_returns_original_text() -> None:
    text = "hello world"
    nav, cleaned = parse_nav_marker(text)
    assert nav is None
    assert cleaned == text


def test_valid_marker_extracts_dict_and_strips_marker() -> None:
    text = 'prefix <!--NAV:{"page": "settings"}--> suffix'
    nav, cleaned = parse_nav_marker(text)
    assert nav == {"page": "settings"}
    # strip() only trims leading/trailing whitespace; interior spacing is kept
    assert cleaned == "prefix  suffix"


def test_marker_strip_removes_marker_only() -> None:
    text = 'before <!--NAV:{"x": 1}--> after'
    _, cleaned = parse_nav_marker(text)
    assert "<!--NAV" not in cleaned
    assert cleaned == "before  after"


def test_malformed_json_leaves_text_unchanged() -> None:
    text = "keep <!--NAV:not-json--> intact"
    nav, cleaned = parse_nav_marker(text)
    assert nav is None
    assert cleaned == text


def test_non_dict_json_is_returned_as_is() -> None:
    text = '<!--NAV:[1, 2, 3]--> rest'
    nav, cleaned = parse_nav_marker(text)
    assert nav == [1, 2, 3]
    assert cleaned == "rest"


def test_marker_at_start_cleans_leading_space() -> None:
    text = '<!--NAV:{"a": 1}-->body'
    nav, cleaned = parse_nav_marker(text)
    assert nav == {"a": 1}
    assert cleaned == "body"


def test_marker_requires_colon_prefix() -> None:
    text = "plain comment <!--NAV without json-->"
    nav, cleaned = parse_nav_marker(text)
    assert nav is None
    assert cleaned == text
