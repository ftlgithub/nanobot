# Pre-bundled TUI binaries for the offline installer (ticket 04)

Fetched from upstream GitHub releases; re-downloadable, NOT versioned in git
(see root `.gitignore`: `nanobot/tui/bin/nanobot-tui-*`).

| Asset | Release | SHA-256 |
|---|---|---|
| `nanobot-tui-darwin-arm64.zip` (25,277,146 B) | v0.3.5 | `8694d7be3e033b65fe445c025faa1a20bdb2eeb67ea88dda4123a2d6f8b1428b` |
| `nanobot-tui-linux-x64.zip` (43,320,003 B) | v0.3.5 | `97613f010bebb4462a17c7d6ad0ec371bc9faea16898911fd4473a05d9cdafac` |

Re-fetch:

```bash
cd nanobot/tui/bin
gh release download v0.3.5 --repo HKUDS/nanobot \
  --pattern "nanobot-tui-darwin-arm64.zip*" \
  --pattern "nanobot-tui-linux-x64.zip*"
sha256sum -c *.sha256
```

Layout expected by `nanobot/cli/tui_launcher.py`: the extracted binary must
exist at `nanobot/tui/bin/nanobot-tui-<system>-<machine>` (no `.zip` suffix),
executable bit set. Unpack the platform zip during tarball assembly:

```bash
unzip -o -q nanobot-tui-darwin-arm64.zip nanobot-tui-darwin-arm64
chmod +x nanobot-tui-darwin-arm64
```

Verified 2026-09-16: darwin-arm64 binary executes on this machine.
