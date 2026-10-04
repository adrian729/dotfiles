#!/usr/bin/env python3
"""Apply the portable Codex config while retaining locally installed integrations."""

import copy
import datetime
import json
import os
from pathlib import Path
import sys
import tempfile
import tomllib


# Preserve complete named entries; a repo entry with the same name replaces it.
INTEGRATION_TABLES = ("mcp_servers", "plugins", "marketplaces", "apps")
INTEGRATION_KEYS = (
    "mcp_oauth_credentials_store", "mcp_oauth_callback_port",
    "mcp_oauth_callback_url", "mcp_enterprise_managed_auth",
)


def merge(baseline, local):
    result = copy.deepcopy(baseline)
    for key in INTEGRATION_TABLES:
        if key in local:
            result[key] = {**local[key], **baseline.get(key, {})}
    for key in INTEGRATION_KEYS:
        if key in local and key not in baseline:
            result[key] = local[key]

    # Keep per-skill enablement, but reset general skill settings (e.g. budgets).
    skills = {}
    for config in (local, baseline):
        for entry in config.get("skills", {}).get("config", []):
            skills[entry["path"]] = entry
    if skills:
        result.setdefault("skills", {})["config"] = list(skills.values())
    return result


def value_toml(value):
    """Serialize parsed TOML values without requiring a third-party package."""
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False).replace("\x7f", "\\u007f")
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, (datetime.datetime, datetime.date, datetime.time)):
        return value.isoformat()
    if isinstance(value, list):
        return "[" + ", ".join(value_toml(item) for item in value) + "]"
    if isinstance(value, dict):
        return "{ " + ", ".join(
            f"{value_toml(key)} = {value_toml(item)}" for key, item in value.items()
        ) + " }"
    raise TypeError(f"Unsupported TOML value type: {type(value).__name__}")


def dump_toml(data, path=()):
    lines = []
    if path:
        lines.append("[" + ".".join(value_toml(key) for key in path) + "]")
    for key, value in data.items():
        if not isinstance(value, dict):
            lines.append(f"{value_toml(key)} = {value_toml(value)}")
    for key, value in data.items():
        if isinstance(value, dict):
            lines.extend(("", dump_toml(value, (*path, key))))
    return "\n".join(lines)


def install(baseline_path, target):
    # A folded Stow directory would put machine-local integrations in the repo.
    repo = Path(__file__).resolve().parent.parent
    if target.parent.is_symlink() or target.parent.resolve().is_relative_to(repo):
        raise ValueError("config directory is symlinked or inside the dotfiles repo; unstow and restow with --no-folding first")
    baseline = tomllib.loads(baseline_path.read_text(encoding="utf-8"))
    if target.is_symlink() and not target.exists():
        raise ValueError("config.toml is a broken symlink; repair it before installing")
    previous = target.read_bytes() if target.exists() else None
    local = tomllib.loads(previous.decode("utf-8")) if previous is not None else {}
    merged = merge(baseline, local)
    output = dump_toml(merged) + "\n"
    tomllib.loads(output)  # Validate the generated TOML before touching the target.

    target.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".config.toml.", dir=target.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(output)
            stream.flush()
            os.fsync(stream.fileno())
        current = target.read_bytes() if target.exists() else None
        if current != previous:
            raise ValueError("config.toml changed during installation; retry")
        os.replace(tmp, target)  # Replace a file symlink, never write through it.
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Usage: merge_config.py BASELINE TARGET")
    try:
        install(Path(sys.argv[1]), Path(sys.argv[2]).absolute())
    except (OSError, ValueError, TypeError, KeyError) as error:
        # TOML error excerpts can contain credentials; do not echo their contents.
        if isinstance(error, tomllib.TOMLDecodeError):
            detail = "invalid TOML; fix the source or live config before installing"
        else:
            detail = str(error)
        sys.exit(f"Codex config not installed: {detail}")
