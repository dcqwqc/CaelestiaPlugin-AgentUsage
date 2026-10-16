"""Guard the condensed Agents presentation against accidental extra rows."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CompactLayoutTests(unittest.TestCase):
    def test_antigravity_two_inline_pool_rows(self):
        row = (ROOT / "components/AgentRow.qml").read_text()
        self.assertIn('model: root.isAntigravity && root.available ? (root.agent?.pools ?? []) : []', row)
        self.assertIn('compact: true', row)
        self.assertIn('label: modelData.id === "gemini" ? qsTr("Gemini") : qsTr("Claude/GPT")', row)
        self.assertNotIn('Cached ·', row)
        # Every gauge uses the shared column widths so bars align across agents.
        self.assertEqual(row.count("labelWidth: root.shortLabelWidth"), 2)
        self.assertEqual(row.count("labelWidth: root.weekLabelWidth"), 2)
        self.assertNotIn('agent?.source', row)

    def test_no_redundant_card_heading(self):
        card = (ROOT / "cards/AgentUsageCard.qml").read_text()
        self.assertNotIn('qsTr("Limits")', card)


if __name__ == "__main__":
    unittest.main()
