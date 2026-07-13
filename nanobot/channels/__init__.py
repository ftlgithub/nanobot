"""Chat channels module with plugin architecture."""

from __future__ import annotations

from typing import TYPE_CHECKING, Any

from nanobot.channels.base import BaseChannel

if TYPE_CHECKING:
    from nanobot.channels.manager import ChannelManager

__all__ = ["BaseChannel", "ChannelManager"]


def __getattr__(name: str) -> Any:
    """Preserve the public manager export without importing WebUI on package load."""
    if name == "ChannelManager":
        from nanobot.channels.manager import ChannelManager

        return ChannelManager
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
