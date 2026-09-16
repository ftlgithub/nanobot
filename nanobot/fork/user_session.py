"""Fork: user-to-session association map (re-export).

The canonical implementation lives in ``nanobot.webui.user_session_map``;
this module is the unified fork-facing entry point.
"""

from __future__ import annotations

from nanobot.webui.user_session_map import get_instance

__all__ = ["get_instance"]
