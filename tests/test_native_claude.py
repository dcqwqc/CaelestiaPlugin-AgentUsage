"""Native Claude statusLine capture: stdin-only, no OAuth/HTTP calls."""
import importlib.machinery
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "claude-statusline-capture"
COLLECTOR = ROOT / "scripts" / "agent-usage"


class NativeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.cache = Path(self.temp.name)
        self.env = dict(os.environ, XDG_CACHE_HOME=str(self.cache))

    def call(self, payload):
        return subprocess.run([str(SCRIPT)], input=json.dumps(payload),
                              capture_output=True, text=True, env=self.env,
                              check=True)

    def test_records_both_quotas_not_private_payload(self):
        payload = {
            "session_id": "sensitive-session-identifier",
            "prompt": "sensitive-user-prompt",
            "rate_limits": {
                "five_hour": {"used_percentage": 47, "resets_at": 1800000000},
                "seven_day": {"used_percentage": 69, "resets_at": 1800400000},
            },
        }
        result = self.call(payload)
        self.assertEqual(result.stdout.strip(), "5h 47% · 7d 69%")
        path = self.cache / "caelestia-agent-usage-claude-last-good.json"
        saved = path.read_text()
        self.assertNotIn("sensitive-session-identifier", saved)
        self.assertNotIn("sensitive-user-prompt", saved)
        d = json.loads(saved)["reading"]
        self.assertEqual((d["fiveHour"], d["weekly"]), (.47, .69))
        self.assertEqual((d["fiveHourResets"], d["weeklyResets"]),
                         (1800000000, 1800400000))
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_missing_native_field_preserves_last_good(self):
        self.call({"rate_limits": {
            "five_hour": {"used_percentage": 19, "resets_at": 1800000000},
            "seven_day": {"used_percentage": 23, "resets_at": 1800400000},
        }})
        self.call({"rate_limits": None, "model": {"display_name": "Opus"}})
        d = json.loads((self.cache / "caelestia-agent-usage-claude-last-good.json").read_text())
        self.assertEqual(d["reading"]["fiveHour"], .19)
        self.assertEqual(d["reading"]["weekly"], .23)

    def test_partial_bucket_keeps_previous_other_window(self):
        self.call({"rate_limits": {
            "five_hour": {"used_percentage": 19},
            "seven_day": {"used_percentage": 23},
        }})
        self.call({"rate_limits": {"five_hour": {"used_percentage": 29}}})
        d = json.loads((self.cache / "caelestia-agent-usage-claude-last-good.json").read_text())
        self.assertEqual(d["reading"]["fiveHour"], .29)
        self.assertEqual(d["reading"]["weekly"], .23)

    def test_invalid_percentage_not_saved(self):
        self.call({"rate_limits": {"five_hour": {"used_percentage": -9}}})
        self.assertFalse((self.cache / "caelestia-agent-usage-claude-last-good.json").exists())

    def test_recent_native_skips_http_and_credential_file(self):
        path = self.cache / "caelestia-agent-usage-claude-last-good.json"
        path.write_text(json.dumps({
            "generated": int(time.time()),
            "reading": {
                "id": "claude", "name": "Claude Code", "available": True,
                "source": "claude-statusline", "fiveHour": .45,
                "weekly": .67, "stale": False,
            },
        }))
        module = types.ModuleType("native_quota_test_module")
        importlib.machinery.SourceFileLoader(module.__name__, str(COLLECTOR)).exec_module(module)
        module.CLAUDE_LAST_GOOD = str(path)
        module.CLAUDE_CREDS = str(self.cache / "nonexistent-credentials.json")
        with patch.object(module.urllib.request, "urlopen") as urlopen:
            data = module.claude(1)
        urlopen.assert_not_called()
        self.assertTrue(data["available"])
        self.assertEqual(data["weekly"], .67)


if __name__ == "__main__":
    unittest.main()
