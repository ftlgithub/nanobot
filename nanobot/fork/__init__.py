"""Fork patch layer: centralized home for fork-specific modifications.

All fork-local behavior lives under this package so that upstream rebases
never touch fork logic. Upstream files keep only thin call points annotated
with ``# FORK-HOOK`` comments (see ``docs/fork-integration.md``).
"""

from __future__ import annotations

from nanobot.fork.user_session import get_instance as get_user_map

__all__ = ["get_user_map"]
