"""Dependency-free management manifests for built-in channels.

Runtime channel modules may import optional platform SDKs.  Their adjacent
manifest modules keep setup discovery cheap and safe for disabled channels.
"""

from __future__ import annotations

import importlib
from functools import lru_cache

from nanobot.channels.contracts import ChannelSetupSpec


@lru_cache(maxsize=None)
def load_builtin_setup_spec(name: str) -> ChannelSetupSpec | None:
    """Load ``nanobot.channels.manifests.<name>.SETUP_SPEC`` when present."""
    if not name.isidentifier() or name.startswith("_"):
        return None

    module_name = f"{__name__}.{name}"
    try:
        module = importlib.import_module(module_name)
    except ModuleNotFoundError as exc:
        if exc.name == module_name:
            return None
        raise

    spec = getattr(module, "SETUP_SPEC", None)
    if not isinstance(spec, ChannelSetupSpec):
        raise TypeError(f"{module_name}.SETUP_SPEC must be a ChannelSetupSpec")
    return spec
