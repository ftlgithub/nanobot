"""Fork: CORS response header helpers."""

from __future__ import annotations

CORS_ALLOW_ALL = "*"


def cors_header(origin: str) -> tuple[str, str]:
    """Build an ``Access-Control-Allow-Origin`` header pair for *origin*."""
    return ("Access-Control-Allow-Origin", origin)
