"""Resolve channel-owned setup contracts for settings consumers."""

from __future__ import annotations

from typing import Any

from nanobot.channels.contracts import ChannelSetupSpec
from nanobot.channels.manifests import load_builtin_setup_spec


def channel_setup_spec(
    name: str,
    channel_cls: type[Any] | None = None,
) -> ChannelSetupSpec | None:
    """Return the built-in manifest or external plugin setup contract."""
    manifest = load_builtin_setup_spec(name)
    if manifest is not None:
        return manifest
    if channel_cls is None:
        return None

    spec = channel_cls.setup_spec()
    if spec is not None and not isinstance(spec, ChannelSetupSpec):
        raise TypeError(
            f"{channel_cls.__name__}.setup_spec() must return ChannelSetupSpec or None"
        )
    return spec
