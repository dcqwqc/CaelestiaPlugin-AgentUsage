"""Codex multi-host quota regression tests: freshness, reset, and UI semantics."""
import importlib.machinery
import importlib.util
import json
import os
import tempfile
import types
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/agent-usage"
READER = ROOT / "scripts/codex_rate_limits.py"


def load_collector():
    module = types.ModuleType("agent_usage_codex_tests")
    importlib.machinery.SourceFileLoader(module.__name__, str(SCRIPT)).exec_module(module)
    module.CODEX_READER = str(READER)
    module.CODEX_REMOTE_HOST = "philipedia"
    return module


class CodexSourcesTests(unittest.TestCase):
    def setUp(self):
        self.mod = load_collector()
        self.now = 1792110000
        self.remote = {
            "observedAt": self.now - 180,
            "primary": {"used_percent": 100.0, "window_minutes": 300,
                        "resets_at": self.now + 600},
            "secondary": {"used_percent": 36.0, "window_minutes": 10080,
                          "resets_at": self.now + 500000},
        }
        self.local = {
            "observedAt": self.now - 40000,
            "primary": {"used_percent": 45.0, "window_minutes": 300,
                        "resets_at": self.now - 10000},
            "secondary": {"used_percent": 7.0, "window_minutes": 10080,
                          "resets_at": self.now + 500000},
        }

    def collect_codex(self, local=None, remote=None):
        data = {"": local, "philipedia": remote}
        with patch.object(self.mod, "_codex_snapshot",
                          side_effect=lambda host, timeout: data.get(host)),              patch.object(self.mod.time, "time", return_value=self.now):
            return self.mod.codex(5)

    def test_remote_recent_wins_over_old_local(self):
        result = self.collect_codex(self.local, self.remote)
        self.assertEqual(result["source"], "Philipedia")
        self.assertEqual(result["fiveHour"], 1)
        self.assertEqual(result["weekly"], .36)
        self.assertFalse(result["stale"])  # 3 min old still counts as live

    def test_old_local_alone_is_still_shown(self):
        result = self.collect_codex(self.local, None)
        self.assertTrue(result["available"])
        self.assertTrue(result["stale"])

    def test_expired_window_has_refilled(self):
        remote = dict(self.remote)
        remote["primary"] = dict(remote["primary"], resets_at=self.now - 1)
        result = self.collect_codex(None, remote)
        self.assertTrue(result["available"])
        self.assertEqual(result["fiveHour"], 0)
        self.assertEqual(result["weekly"], .36)
        self.assertTrue(result["stale"])

    def test_both_expired_still_available(self):
        remote = dict(self.remote)
        remote["primary"] = dict(remote["primary"], resets_at=self.now - 1)
        remote["secondary"] = dict(remote["secondary"], resets_at=self.now - 1)
        result = self.collect_codex(None, remote)
        self.assertTrue(result["available"])
        self.assertEqual((result["fiveHour"], result["weekly"]), (0, 0))

    def test_fallback_refills_expired_window(self):
        previous = {
            "id": "codex", "available": True, "observedAt": self.now - 100,
            "fiveHour": 1.0, "fiveHourResets": self.now - 1,
            "weekly": .36, "weeklyResets": self.now + 500000,
        }
        fallback = self.mod.unavailable("codex", "Codex", "offline")
        with patch.object(self.mod.time, "time", return_value=self.now):
            result = self.mod._known_reading("codex", fallback, {"codex": previous})
        self.assertEqual(result["fiveHour"], 0)
        self.assertEqual(result["weekly"], .36)
        self.assertTrue(result["stale"])

    def test_fallback_keeps_very_old_snapshot(self):
        previous = {
            "id": "codex", "available": True,
            "observedAt": self.now - 30 * 86400,
            "fiveHour": 1.0, "weekly": .36,
        }
        fallback = self.mod.unavailable("codex", "Codex", "offline")
        with patch.object(self.mod.time, "time", return_value=self.now):
            result = self.mod._known_reading("codex", fallback, {"codex": previous})
        self.assertTrue(result["available"])
        self.assertTrue(result["stale"])

    def test_invalid_ssh_hostname_rejected_without_executing(self):
        with patch.object(self.mod.subprocess, "run") as run:
            self.assertIsNone(self.mod._codex_snapshot("-oBad=1", 5))
            run.assert_not_called()

    def test_remaining_gauge_is_explicit(self):
        gauge = (ROOT / "components/AgentGauge.qml").read_text()
        card = (ROOT / "cards/AgentUsageCard.qml").read_text()
        self.assertIn("1 - value", gauge)
        self.assertIn("root.remaining * 100", gauge)
        self.assertIn('qsTr("Remaining")', card)


class CodexReaderTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        spec = importlib.util.spec_from_file_location("codex_rate_limits", READER)
        self.mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.mod)
        self.root = Path(self.tmp.name)

    def make_log(self, name, entries, mtime):
        path = self.root / ("rollout-" + name + ".jsonl")
        path.write_text("\n".join(json.dumps(x) for x in entries) + "\n")
        os.utime(path, (mtime, mtime))
        return path

    def entry(self, stamp, short, weekly):
        return {
            "timestamp": stamp, "payload": {
                "rate_limits": {"primary": short, "secondary": weekly}
            }
        }

    def test_null_latest_records_skipped_and_concurrent_conservative(self):
        a = {"used_percent": 99, "window_minutes": 300, "resets_at": 5000000}
        b = {"used_percent": 35, "window_minutes": 10080, "resets_at": 8000000}
        c = dict(a, used_percent=100)
        d = dict(b, used_percent=36)
        self.make_log("a", [
            self.entry("2026-10-16T00:00:05Z", a, b),
            self.entry("2026-10-16T00:00:08Z", None, None),
        ], 1792100008)
        self.make_log("b", [
            self.entry("2026-10-16T00:00:03Z", c, d),
            self.entry("2026-10-16T00:00:09Z", None, None),
        ], 1792100009)
        result = self.mod.latest(str(self.root))
        self.assertEqual(result["primary"]["used_percent"], 100)
        self.assertEqual(result["secondary"]["used_percent"], 36)
        self.assertNotIn("payload", result)

    def test_missing_or_malformed_is_not_zero_usage(self):
        self.make_log("missing", [
            self.entry("2026-10-16T00:00:05Z", None, None),
        ], 1792100008)
        self.assertIsNone(self.mod.latest(str(self.root)))


if __name__ == "__main__":
    unittest.main()
