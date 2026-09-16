"""Tests for the fork navigation dispatch hook in ChannelManager._send_once."""

from __future__ import annotations

from unittest.mock import AsyncMock

import pytest

from nanobot.bus.events import OutboundMessage
from nanobot.bus.outbound_events import StreamedResponseEvent, StreamEndEvent
from nanobot.channels.manager import ChannelManager
from nanobot.config.schema import Config
from tests.channels.test_channel_manager_delta_coalescing import MockChannel  # noqa: F401


class NavSpyChannel(MockChannel):
    """MockChannel with a recorded send_navigation."""

    def __init__(self, config, bus):
        super().__init__(config, bus)
        self.send_navigation = AsyncMock()


@pytest.fixture
def config() -> Config:
    """Minimal config with the websocket channel disabled."""
    return Config.model_validate({"channels": {"websocket": {"enabled": False}}})


def _make_message(*, nav: dict | None, content: str = "hi") -> OutboundMessage:
    metadata = {"_navigation": nav} if nav else {}
    return OutboundMessage(
        channel="mock",
        chat_id="chat-1",
        content=content,
        event=StreamedResponseEvent(),
        metadata=metadata,
    )


async def test_nav_dispatch_called_with_nav_data(config) -> None:  # type: ignore[no-untyped-def]
    channel = NavSpyChannel(config, bus=None)
    nav = {"page": "settings"}
    await ChannelManager._send_once(channel, _make_message(nav=nav))
    channel.send_navigation.assert_awaited_once_with("chat-1", nav)


async def test_no_navigation_metadata_skips_dispatch(config) -> None:  # type: ignore[no-untyped-def]
    channel = NavSpyChannel(config, bus=None)
    await ChannelManager._send_once(channel, _make_message(nav=None))
    channel.send_navigation.assert_not_awaited()


async def test_stream_end_event_dispatches_navigation(config) -> None:  # type: ignore[no-untyped-def]
    channel = NavSpyChannel(config, bus=None)
    nav = {"page": "threads"}
    msg = _make_message(nav=nav)
    msg.event = StreamEndEvent(content="done")
    await ChannelManager._send_once(channel, msg)
    channel.send_navigation.assert_awaited_once_with("chat-1", nav)
