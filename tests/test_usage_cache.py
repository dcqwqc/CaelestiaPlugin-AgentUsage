"""Tests of independent Antigravity pools and persistent last-known usage."""
import importlib.machinery
import json
import tempfile
import time
import types
import unittest
from pathlib import Path
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / "scripts" / "agent-usage"


class CacheTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.mod = types.ModuleType("agent_usage_cache_tests")
        importlib.machinery.SourceFileLoader(
            "agent_usage_cache_tests", str(SOURCE)
        ).exec_module(self.mod)
        self.mod.LAST_GOOD = str(self.root / "last-good.json")
        self.mod.AGY_BIN = str(self.root / "agy")
        self.root.joinpath("agy").write_text("# mock executable\n")
        self.root.joinpath("agy").chmod(0o700)

    @staticmethod
    def record(pool="Gemini Models", short=78, week=42):
        return (f"{pool}\tFive Hour Limit Remaining\t{short}%\t2026-10-15T15:00:00Z\n"
                f"{pool}\tWeekly Limit Remaining\t{week}%\t2026-10-22T15:00:00Z\n")

    def run_agent(self, stdout, returncode=0):
        result = types.SimpleNamespace(stdout=stdout, returncode=returncode)
        with patch.object(self.mod.subprocess, "run", return_value=result):
            return self.mod.antigravity(5)

    def test_two_independent_pools_and_order(self):
        text = self.record(short=77, week=30) + self.record(
            "Claude and GPT models", short=9, week=87
        )
        result = self.run_agent(text)
        self.assertTrue(result["available"])
        google, claude = result["pools"]
        self.assertEqual([p["id"] for p in result["pools"]],
                         ["gemini", "claude-gpt"])
        self.assertAlmostEqual(google["fiveHour"], .23)
        self.assertAlmostEqual(google["weekly"], .70)
        self.assertAlmostEqual(claude["fiveHour"], .91)
        self.assertAlmostEqual(claude["weekly"], .13)
        self.assertFalse(any(p["stale"] for p in result["pools"]))

    def test_failure_retains_both_stale_pools(self):
        initial = self.run_agent(self.record(short=77) + self.record(
            "Claude and GPT models", short=9
        ))
        self.mod.private_json(self.mod.LAST_GOOD,
                              {"agents": {"antigravity": initial}})
        failure = self.run_agent("", returncode=1)
        self.assertEqual(len(failure["pools"]), 2)
        self.assertTrue(all(p["stale"] for p in failure["pools"]))
        self.assertTrue(failure["available"])
        for before, after in zip(initial["pools"], failure["pools"]):
            self.assertEqual(before["fiveHour"], after["fiveHour"])
            self.assertEqual(before["weekly"], after["weekly"])
            self.assertEqual(before["observedAt"], after["observedAt"])

    def test_partial_response_does_not_erase_other_pool(self):
        initial = self.run_agent(self.record(short=75) + self.record(
            "Claude and GPT models", short=80
        ))
        self.mod.private_json(self.mod.LAST_GOOD,
                              {"agents": {"antigravity": initial}})
        result = self.run_agent(self.record(short=33))
        self.assertAlmostEqual(result["pools"][0]["fiveHour"], .67)
        self.assertFalse(result["pools"][0]["stale"])
        self.assertAlmostEqual(result["pools"][1]["fiveHour"], .20)
        self.assertTrue(result["pools"][1]["stale"])

    def test_partial_window_reuses_its_last_observation(self):
        original = self.run_agent(self.record(short=75,week=45))
        self.mod.private_json(self.mod.LAST_GOOD,
                              {"agents": {"antigravity": original}})
        result = self.run_agent(
            "Gemini Models\tFive Hour Limit Remaining\t45%\t2026-10-15T15:00:00Z\n"
        )
        pool = result["pools"][0]
        self.assertAlmostEqual(pool["fiveHour"], .55)
        self.assertAlmostEqual(pool["weekly"], .55)
        self.assertTrue(pool["stale"])

    def test_failed_collector_keeps_last_known(self):
        def fails(_timeout):
            return self.mod.unavailable("claude", "Claude Code", "rate limited")
        previous = {"id": "claude", "name": "Claude Code", "available": True,
                    "fiveHour": .31, "weekly": .78, "stale": False,
                    "observedAt": 1712345678}
        self.mod.private_json(self.mod.LAST_GOOD,
                              {"agents": {"claude": previous}})
        self.mod.COLLECTORS = [fails]
        result = self.mod.collect(1)["agents"][0]
        self.assertTrue(result["available"])
        self.assertTrue(result["stale"])
        self.assertEqual(result["fiveHour"], .31)
        self.assertEqual(result["observedAt"], 1712345678)


if __name__ == "__main__":
    unittest.main()
