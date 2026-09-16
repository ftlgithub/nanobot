# Offline packaging — dependency locks

Locked dependency sets for the offline installer tarballs, generated from
`pyproject.toml` via `uv pip compile` (Python 3.12).

| File | Target |
|---|---|
| `requirements-macos-arm64.txt` | macOS arm64 |
| `requirements-linux-x64.txt` | Linux x64, glibc 2.17+ (`x86_64-unknown-linux-gnu`) |

Regenerate after any `pyproject.toml` dependency change:

```bash
uv pip compile pyproject.toml --python-version 3.12 \
  -o packaging/locks/requirements-macos-arm64.txt
uv pip compile pyproject.toml --python-version 3.12 \
  --python-platform x86_64-unknown-linux-gnu \
  -o packaging/locks/requirements-linux-x64.txt
```

## Slim production environment

The offline package uses a **slim** env: only `pyproject` `dependencies`
(no `dev`/test extras, no channel extras — websocket needs none).
Verified 2026-09-16: 89 pins, `import nanobot` + all key modules +
both console scripts (`nanobot`, `nanobot-desktop-tui`) work.
Do NOT freeze from a dev conda env (pulls in unrelated packages).
