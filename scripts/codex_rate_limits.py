"""Read Codex's latest *observed* quota snapshot, without credentials or prompts.

This module can also be streamed over SSH to a remote Python interpreter.
Its stdout contains only rate-limit percentages, reset epochs and observation time.
"""
import glob
import json
import os
import time
from datetime import datetime

SCAN = 12


def _find_limits(value):
    if isinstance(value, dict):
        limits = value.get("rate_limits")
        if isinstance(limits, dict):
            return limits
        for child in value.values():
            found = _find_limits(child)
            if found is not None:
                return found
    elif isinstance(value, list):
        for child in value:
            found = _find_limits(child)
            if found is not None:
                return found
    return None


def _window(value):
    if not isinstance(value, dict):
        return None
    try:
        used = float(value["used_percent"])
        minutes = int(value["window_minutes"])
        reset = int(value.get("resets_at") or 0)
    except (ValueError, TypeError, KeyError):
        return None
    if not (0 <= used <= 100 and 0 < minutes <= 10080 and reset >= 0):
        return None
    return {"used_percent": used, "window_minutes": minutes, "resets_at": reset}


def _timestamp(value, fallback):
    try:
        return int(datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp())
    except (AttributeError, TypeError, ValueError, OverflowError):
        return int(fallback)


def _read_file(path):
    try:
        with open(path, errors="replace") as stream:
            lines = stream.readlines()
    except OSError:
        return None
    for line in reversed(lines):
        if '"rate_limits"' not in line:
            continue
        try:
            event = json.loads(line)
        except ValueError:
            continue
        limits = _find_limits(event)
        if not limits:
            continue
        primary = _window(limits.get("primary"))
        secondary = _window(limits.get("secondary"))
        # Recent null/null records are common. Do not confuse them with 0% used.
        if primary is None and secondary is None:
            continue
        return {
            "primary": primary,
            "secondary": secondary,
            "observedAt": _timestamp(event.get("timestamp"), os.path.getmtime(path)),
        }
    return None


def latest(sessions=None):
    root = sessions or os.path.expanduser("~/.codex/sessions")
    files = glob.glob(os.path.join(root, "**", "rollout-*.jsonl"), recursive=True)
    files.sort(key=os.path.getmtime, reverse=True)
    readings = [_read_file(path) for path in files[:SCAN]]
    readings = [r for r in readings if r]
    if not readings:
        return None
    best = max(readings, key=lambda r: r["observedAt"])
    # Concurrent Codex sessions sometimes receive slightly different server
    # counters within seconds. Prefer the conservative quota reading from
    # the same reset window, rather than reporting optimistic availability.
    best = {"observedAt": best["observedAt"],
            "primary": dict(best["primary"]) if best["primary"] else None,
            "secondary": dict(best["secondary"]) if best["secondary"] else None}
    for reading in readings:
        if best["observedAt"] - reading["observedAt"] > 15:
            continue
        for key in ("primary", "secondary"):
            candidate = reading.get(key)
            current = best.get(key)
            if (candidate and current
                    and candidate["resets_at"] == current["resets_at"]
                    and candidate["window_minutes"] == current["window_minutes"]):
                current["used_percent"] = max(current["used_percent"],
                                              candidate["used_percent"])
    return best


if __name__ == "__main__":
    print(json.dumps(latest() or {}))
