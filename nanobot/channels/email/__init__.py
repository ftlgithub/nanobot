"""Email channel package with lazy runtime compatibility exports."""

from __future__ import annotations

import importlib
from typing import Any


def __getattr__(name: str) -> Any:
    if name.startswith("__"):
        raise AttributeError(name)
    return getattr(importlib.import_module(f"{__name__}.runtime"), name)


def __dir__() -> list[str]:
    return sorted(set(globals()) | set(dir(importlib.import_module(f"{__name__}.runtime"))))
