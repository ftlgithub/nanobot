"""Fork: NAV marker parsing and navigation dispatch helpers."""

from __future__ import annotations

import json
import re
from typing import Any

_NAV_MARKER_RE = re.compile(r"<!--NAV:(.*?)-->")


def parse_nav_marker(text: str) -> tuple[dict[str, Any] | None, str]:
    """Extract a ``<!--NAV:{json}-->`` marker from *text*.

    Returns ``(nav_dict, cleaned_text)`` where *cleaned_text* has the marker
    stripped. When no marker is present, or the embedded JSON is malformed,
    returns ``(None, text)`` unchanged (malformed markers are left in place,
    matching the original inline behavior).
    """
    match = _NAV_MARKER_RE.search(text)
    if not match:
        return None, text
    try:
        nav_data = json.loads(match.group(1))
    except json.JSONDecodeError:
        return None, text
    cleaned = (text[: match.start()] + text[match.end() :]).strip()
    return nav_data, cleaned
