"""User↔session association map.

Maintains a mapping from session_id → user_id in a separate JSON file,
so Gateway can filter session lists by user without modifying session JSONL.

Storage: ~/.nanobot/workspace/user_session_map.json
Structure: {"websocket:uuid": "admin", ...}
"""

from __future__ import annotations

import json
import os
import threading

DEFAULT_DATA_DIR = os.path.expanduser("~/.nanobot/workspace")
MAP_FILENAME = "user_session_map.json"


class UserSessionMap:
    """Thread-safe mapping from session_id → user_id, persisted as JSON."""

    def __init__(self, data_dir: str = DEFAULT_DATA_DIR):
        self._path = os.path.join(data_dir, MAP_FILENAME)
        self._lock = threading.Lock()
        self._map: dict[str, str] = {}
        self._load()

    # -- persistence ---------------------------------------------------------

    def _load(self) -> None:
        try:
            if os.path.exists(self._path):
                with open(self._path, encoding="utf-8") as f:
                    self._map = json.load(f)
            else:
                self._map = {}
        except (json.JSONDecodeError, OSError):
            self._map = {}

    def _save(self) -> None:
        try:
            os.makedirs(os.path.dirname(self._path), exist_ok=True)
            with open(self._path, "w", encoding="utf-8") as f:
                json.dump(self._map, f, ensure_ascii=False, indent=2)
        except OSError:
            pass  # best-effort persistence

    # -- public API ----------------------------------------------------------

    def associate(self, user_id: str, session_id: str) -> None:
        """Link a user to a session (called on new_chat)."""
        if not user_id or not session_id:
            return
        with self._lock:
            self._map[session_id] = user_id
            self._save()

    def dissociate(self, session_id: str) -> None:
        """Remove mapping (called on session delete)."""
        if not session_id:
            return
        with self._lock:
            self._map.pop(session_id, None)
            self._save()

    def get_owner(self, session_id: str) -> str | None:
        """Get the user who owns a session, or None if unmapped."""
        return self._map.get(session_id)

    def filter_sessions(
        self, sessions: list[dict], user_id: str
    ) -> list[dict]:
        """Filter sessions list to only those visible to *user_id*.

        Rules:
        - Sessions with no mapping (legacy) are visible to everyone.
        - Sessions mapped to *user_id* are visible.
        - Sessions mapped to a *different* user_id are hidden.
        """
        if not user_id or not sessions:
            return sessions
        return [
            s
            for s in sessions
            if not self.get_owner(s.get("key", ""))  # legacy: no mapping
            or self.get_owner(s["key"]) == user_id  # owned by this user
        ]

    def gc(self, valid_session_ids: set[str]) -> None:
        """Remove mappings for sessions that no longer exist on disk."""
        stale = [sid for sid in self._map if sid not in valid_session_ids]
        if not stale:
            return
        with self._lock:
            for sid in stale:
                self._map.pop(sid, None)
            self._save()


# Module-level singleton -----------------------------------------------------

_inst: UserSessionMap | None = None


def get_instance(data_dir: str | None = None) -> UserSessionMap:
    global _inst
    if _inst is None:
        _inst = UserSessionMap(data_dir or DEFAULT_DATA_DIR)
    return _inst
