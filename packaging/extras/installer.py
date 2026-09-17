#!/usr/bin/env python3
"""nanobot offline extras installer (stdlib only, any Python 3.8+).

Installs internal CLI Apps, skills and an MCP server into an existing
offline nanobot install. Never touches the network.

Deliberately does NOT call nanobot's own install()/install_skill(): those
delete ``workspace/skills/cli-app-*`` and move skills into plugins that need
enabling. Here we seed ``installed.json`` directly and drop the real skill
files, which keeps names identical to a dev machine and avoids the deleted
skill / duplicate-name behaviour.

Steps:
  1. resolve + validate <prefix> and <workspace>
  2. pip install --no-index --no-deps the bundled internal wheels
  3. copy the local chart CLI app
  4. symlink CLI entry points into <prefix>/bin (already on PATH)
  5. seed <data>/cli-apps/installed.json
  6. copy skills into <workspace>/skills
  7. install the MCP server + merge tools.mcpServers (command rewritten)
  8. print a summary
Idempotent: re-running yields the same result.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

CLI_APPS = (
    {
        "name": "dct-north-cli",
        "version": "0.1.0",
        "strategy": "pip",
        "entry_point": "dct-north-cli",
        "wheel_glob": "dct_north_cli-*.whl",
    },
    {
        "name": "cli-anything-asset-historical-data",
        "version": "0.1.0",
        "strategy": "pip",
        "entry_point": "cli-anything-asset-historical-data",
        "wheel_glob": "cli_anything_asset_historical_data-*.whl",
    },
    {
        "name": "chart",
        "version": "0.2.0",
        "strategy": "local",
        "entry_point": "chart/cli-chart",
        "wheel_glob": None,
    },
)

SKILLS = (
    "alert-analysis",
    "dynamic-monitor",
    "doc-page",
    "cli-app-dct-north-cli",
    "cli-app-chart",
    "cli-app-cli-anything-asset-historical-data",
)

MCP_NAME = "fastgpt-knowledge"


class InstallError(Exception):
    """User-actionable install failure."""


def log(msg: str) -> None:
    print(msg, flush=True)


def resolve_prefix(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit).expanduser().resolve()
    found = shutil.which("nanobot")
    if not found:
        raise InstallError(
            "cannot locate nanobot on PATH; pass <nanobot-prefix> explicitly "
            "(the directory that contains bin/ and python/)"
        )
    # <prefix>/bin/nanobot -> <prefix>
    return Path(os.path.realpath(found)).resolve().parent.parent


def validate_prefix(prefix: Path) -> Path:
    if not prefix.is_dir():
        raise InstallError(f"prefix is not a directory: {prefix}")
    for candidate in ("python/bin/python3", "python/bin/python"):
        if (prefix / candidate).exists():
            return prefix / candidate
    raise InstallError(
        f"{prefix} does not look like an offline nanobot install "
        "(expected python/bin/python3); refusing to install into the wrong Python"
    )


def resolve_workspace(explicit: str | None, data_dir: Path) -> Path:
    if explicit:
        return Path(explicit).expanduser().resolve()
    default = data_dir / "workspace"
    if default.is_dir():
        return default
    raise InstallError(
        "cannot determine workspace; pass <workspace> explicitly "
        "(the directory containing skills/)"
    )


def pip_install(pybin: Path, wheels: list[Path], dry_run: bool) -> None:
    argv = [
        str(pybin),
        "-m",
        "pip",
        "install",
        "--quiet",
        "--no-index",
        "--no-deps",
        "--break-system-packages",
        *[str(w) for w in wheels],
    ]
    log(f"  pip install {len(wheels)} wheel(s)")
    if dry_run:
        return
    result = subprocess.run(argv, capture_output=True, text=True)
    if result.returncode != 0:
        raise InstallError(
            "pip install failed:\n" + (result.stderr or result.stdout or "").strip()
        )


def copy_chart(assets: Path, data_dir: Path, dry_run: bool) -> Path:
    src = assets / "cli-apps" / "chart"
    if not src.is_dir():
        raise InstallError(f"missing bundled chart CLI: {src}")
    dest = data_dir / "cli-apps" / "chart"
    log(f"  chart -> {dest}")
    if dry_run:
        return dest
    if dest.exists():
        shutil.rmtree(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(src, dest)
    script = dest / "cli-chart"
    if script.exists():
        script.chmod(script.stat().st_mode | 0o111)
    return dest


def link_entries(prefix: Path, data_dir: Path, dry_run: bool) -> list[str]:
    bin_dir = prefix / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    linked = []
    for app in CLI_APPS:
        if app["strategy"] == "pip":
            target = prefix / "python" / "bin" / app["entry_point"]
        else:
            target = data_dir / "cli-apps" / app["entry_point"]
        if not dry_run and not target.exists():
            raise InstallError(f"CLI entry point missing after install: {target}")
        link = bin_dir / app["name"]
        log(f"  {link.name} -> {target}")
        if not dry_run:
            if link.is_symlink() or link.exists():
                link.unlink()
            link.symlink_to(target)
        linked.append(app["name"])
    return linked


def seed_installed_json(data_dir: Path, prefix: Path, dry_run: bool) -> None:
    path = data_dir / "cli-apps" / "installed.json"
    log(f"  seeded {path}")
    if dry_run:
        return
    existing: dict = {}
    if path.exists():
        try:
            existing = json.loads(path.read_text(encoding="utf-8")) or {}
        except (OSError, ValueError):
            existing = {}
    apps = existing.get("apps")
    if not isinstance(apps, dict):
        apps = {}
    now = int(time.time())
    for app in CLI_APPS:
        if app["strategy"] == "pip":
            entry_point_path = prefix / "bin" / app["name"]
            entry = {
                "name": app["name"],
                "version": app["version"],
                "entry_point": app["name"],
                "source": "local",
                "strategy": "pip",
                "installed_at": now,
                "entry_point_path": str(entry_point_path),
                "pip_distribution": app["name"],
            }
        else:
            entry_point_path = data_dir / "cli-apps" / app["entry_point"]
            entry = {
                "name": app["name"],
                "version": app["version"],
                "entry_point": str(entry_point_path),
                "source": "local",
                "strategy": "local",
                "installed_at": now,
                "entry_point_path": str(entry_point_path),
            }
        apps[app["name"]] = entry
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps({"schema_version": 1, "apps": apps}, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8",
    )


def copy_skills(assets: Path, workspace: Path, dry_run: bool) -> int:
    src_root = assets / "skills"
    dest_root = workspace / "skills"
    log(f"  skills -> {dest_root}")
    if not dry_run:
        dest_root.mkdir(parents=True, exist_ok=True)
    count = 0
    for name in SKILLS:
        src = src_root / name
        if not (src / "SKILL.md").is_file():
            raise InstallError(f"missing bundled skill: {src}/SKILL.md")
        dest = dest_root / name
        if not dry_run:
            if dest.exists():
                shutil.rmtree(dest)
            shutil.copytree(src, dest)
        count += 1
    return count


def install_mcp(assets: Path, data_dir: Path, pybin: Path, dry_run: bool) -> Path:
    src = assets / "mcp" / MCP_NAME
    if not (src / "server.py").is_file():
        raise InstallError(f"missing bundled MCP server: {src}/server.py")
    dest = data_dir / "mcp" / MCP_NAME
    log(f"  mcp -> {dest}")
    if not dry_run:
        if dest.exists():
            shutil.rmtree(dest)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(src, dest)
    merge_mcp_config(data_dir, dest, pybin, dry_run)
    return dest


def merge_mcp_config(data_dir: Path, mcp_dir: Path, pybin: Path, dry_run: bool) -> None:
    config_path = data_dir / "config.json"
    log(f"  mcp config -> {config_path} (tools.mcpServers.{MCP_NAME})")
    if dry_run:
        return
    data: dict = {}
    if config_path.exists():
        try:
            data = json.loads(config_path.read_text(encoding="utf-8")) or {}
        except (OSError, ValueError):
            raise InstallError(f"existing config is not valid JSON: {config_path}")
        backup = config_path.with_name(f"{config_path.name}.bak-{int(time.time())}")
        shutil.copy2(config_path, backup)
        log(f"  backed up config -> {backup.name}")
    tools = data.get("tools")
    if not isinstance(tools, dict):
        tools = {}
        data["tools"] = tools
    servers = tools.get("mcpServers")
    if not isinstance(servers, dict):
        servers = {}
        tools["mcpServers"] = servers
    previous = servers.get(MCP_NAME)
    entry = dict(previous) if isinstance(previous, dict) else {}
    entry.update(
        {
            "type": "stdio",
            "command": str(pybin),
            "args": [str(mcp_dir / "server.py")],
            "cwd": str(mcp_dir),
        }
    )
    entry.setdefault("env", {})
    entry.setdefault("url", "")
    entry.setdefault("headers", {})
    entry.setdefault("toolTimeout", 120)
    entry.setdefault("enabledTools", ["*"])
    servers[MCP_NAME] = entry
    config_path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="installer.py",
        description="Install nanobot offline extras (CLI apps, skills, MCP).",
    )
    parser.add_argument("--prefix", help="nanobot install prefix (contains bin/ and python/)")
    parser.add_argument("--workspace", help="workspace directory (contains skills/)")
    parser.add_argument("--data-dir", help="instance data dir (default: ~/.nanobot)")
    parser.add_argument(
        "--assets", help="assets directory (default: <script dir>/assets)"
    )
    parser.add_argument("--dry-run", action="store_true", help="plan only, change nothing")
    parser.add_argument("--json", action="store_true", help="print a JSON summary")
    args = parser.parse_args(argv)

    script_dir = Path(__file__).resolve().parent
    assets = Path(args.assets).expanduser().resolve() if args.assets else script_dir / "assets"
    data_dir = (
        Path(args.data_dir).expanduser().resolve()
        if args.data_dir
        else Path(os.path.expanduser("~/.nanobot"))
    )
    summary: dict = {"dry_run": bool(args.dry_run), "steps": []}

    try:
        if not assets.is_dir():
            raise InstallError(
                f"assets not found: {assets}\n"
                "stage them first: packaging/extras/stage-assets.sh"
            )
        prefix = resolve_prefix(args.prefix)
        pybin = validate_prefix(prefix)
        workspace = resolve_workspace(args.workspace, data_dir)
        summary.update(prefix=str(prefix), workspace=str(workspace), data_dir=str(data_dir))
        log(f"prefix:    {prefix}")
        log(f"python:    {pybin}")
        log(f"workspace: {workspace}")
        log(f"data dir:  {data_dir}")

        log("==> installing internal CLI wheels")
        wheels = sorted((assets / "wheels").glob("*.whl"))
        if not wheels:
            raise InstallError(f"no wheels staged in {assets / 'wheels'}")
        for app in CLI_APPS:
            if app["wheel_glob"] and not list((assets / "wheels").glob(app["wheel_glob"])):
                raise InstallError(f"missing wheel for {app['name']} ({app['wheel_glob']})")
        pip_install(pybin, wheels, args.dry_run)
        summary["steps"].append("wheels")

        log("==> installing chart CLI app")
        copy_chart(assets, data_dir, args.dry_run)
        summary["steps"].append("chart")

        log("==> linking CLI entries into prefix/bin")
        summary["linked"] = link_entries(prefix, data_dir, args.dry_run)
        summary["steps"].append("links")

        log("==> seeding installed.json")
        seed_installed_json(data_dir, prefix, args.dry_run)
        summary["steps"].append("installed.json")

        log("==> installing skills")
        summary["skills"] = copy_skills(assets, workspace, args.dry_run)
        summary["steps"].append("skills")

        log("==> installing MCP server")
        install_mcp(assets, data_dir, pybin, args.dry_run)
        summary["steps"].append("mcp")
    except InstallError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(summary, ensure_ascii=False, indent=1))
    else:
        log("")
        log("Done." if not args.dry_run else "Dry run complete (nothing changed).")
        log(f"  CLI apps : {', '.join(summary.get('linked', []))}")
        log(f"  skills   : {summary.get('skills', 0)} installed into {workspace / 'skills'}")
        log(f"  MCP      : {MCP_NAME} (config merged; reload MCP or restart the gateway)")
        log("  Note: CLI entries are symlinked into prefix/bin — that dir must stay on PATH.")
        log("        Skills live per-workspace; a different --workspace needs a re-run.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
