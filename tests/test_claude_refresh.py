"""No-network regressions for Claude Code usage token refresh."""
import importlib.machinery
import io
import json
import os
import tempfile
import time
import types
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError

SOURCE = Path(__file__).resolve().parents[1] / "scripts" / "agent-usage"


class ClaudeRefreshTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.mod = types.ModuleType("agent_usage_tests")
        importlib.machinery.SourceFileLoader(
            "agent_usage_tests", str(SOURCE)
        ).exec_module(self.mod)
        self.mod.CLAUDE_CREDS = str(self.root / ".credentials.json")
        self.mod.CLAUDE_REFRESH_STATE = str(self.root / "retry.json")
        self.mod.CLAUDE_LAST_GOOD = str(self.root / "last-good.json")
        self.original = {
            "claudeAiOauth": {
                "accessToken": "old-access",
                "refreshToken": "old-refresh",
                "expiresAt": int((time.time() - 10) * 1000),
            },
            "otherClaudeConfig": {"mustStay": True},
        }
        self.root.joinpath(".credentials.json").write_text(json.dumps(self.original))

    def test_json_refresh_and_private_atomic_storage(self):
        response = io.BytesIO(json.dumps({
            "access_token": "new-access",
            "refresh_token": "new-refresh",
            "expires_in": 28800,
        }).encode())
        def fetch(request, timeout):
            self.assertEqual(request.get_header("Content-type"), "application/json")
            self.assertEqual(json.loads(request.data), {
                "grant_type": "refresh_token",
                "refresh_token": "old-refresh",
                "client_id": self.mod.CLAUDE_CLIENT_ID,
            })
            return response
        with patch.object(self.mod.urllib.request, "urlopen", side_effect=fetch) as call:
            refreshed = self.mod.refresh_claude_token(self.original["claudeAiOauth"])
        self.assertEqual(call.call_count, 1)
        self.assertEqual(refreshed["accessToken"], "new-access")
        creds = json.loads(Path(self.mod.CLAUDE_CREDS).read_text())
        self.assertEqual(creds["claudeAiOauth"]["refreshToken"], "new-refresh")
        self.assertEqual(creds["otherClaudeConfig"], {"mustStay": True})
        self.assertEqual(os.stat(self.mod.CLAUDE_CREDS).st_mode & 0o777, 0o600)

    def test_429_backs_off_without_discarding_credentials(self):
        error = HTTPError("https://example.invalid", 429, "Too Many Requests",
                          {"Retry-After": "300"}, io.BytesIO(b"{}"))
        with patch.object(self.mod.urllib.request, "urlopen", side_effect=error) as call:
            self.assertIsNone(self.mod.refresh_claude_token(self.original["claudeAiOauth"]))
            self.assertIsNone(self.mod.refresh_claude_token(self.original["claudeAiOauth"]))
        self.assertEqual(call.call_count, 1)
        self.assertEqual(self.mod.refresh_error_status(), 429)
        state = self.mod.read_json(self.mod.CLAUDE_REFRESH_STATE)
        self.assertGreater(state["retryAfter"], time.time() + 290)
        self.assertEqual(json.loads(Path(self.mod.CLAUDE_CREDS).read_text()),
                         self.original)

    def test_cached_reading_is_marked_stale_not_guessed(self):
        previous = {"id": "claude", "name": "Claude Code",
                    "available": True, "fiveHour": .24, "weekly": .6}
        self.mod.private_json(self.mod.CLAUDE_LAST_GOOD,
                              {"generated": int(time.time()), "reading": previous})
        result = self.mod.claude_usage_fallback("Usage rate-limited")
        self.assertTrue(result["stale"])
        self.assertEqual(result["fiveHour"], .24)
        self.assertEqual(result["detail"], "Usage rate-limited")
        self.mod.private_json(self.mod.CLAUDE_LAST_GOOD,
                              {"generated": int(time.time()) - 1900, "reading": previous})
        result = self.mod.claude_usage_fallback("Usage rate-limited")
        self.assertTrue(result["available"])
        self.assertTrue(result["stale"])
        self.assertTrue(result["configured"])
        self.assertEqual(result["fiveHour"], .24)
        self.assertGreater(int(time.time()) - result["observedAt"], 1800)

    def test_concurrent_newer_token_is_not_overwritten(self):
        self.original["claudeAiOauth"]["accessToken"] = "already-renewed"
        self.original["claudeAiOauth"]["expiresAt"] = int((time.time() + 3600)*1000)
        Path(self.mod.CLAUDE_CREDS).write_text(json.dumps(self.original))
        with patch.object(self.mod.urllib.request, "urlopen") as urlopen:
            result = self.mod.refresh_claude_token({"refreshToken": "old-refresh"})
        urlopen.assert_not_called()
        self.assertEqual(result["accessToken"], "already-renewed")


if __name__ == "__main__":
    unittest.main()
