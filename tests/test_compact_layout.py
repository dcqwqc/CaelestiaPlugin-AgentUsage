"""Guard the condensed Agents presentation against accidental extra rows."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CompactLayoutTests(unittest.TestCase):
    def test_antigravity_two_inline_pool_rows(self):
        row = (ROOT / "components/AgentRow.qml").read_text()
        self.assertIn('model: root.agent?.pools ?? []', row)
        self.assertIn('compact: true', row)
        self.assertIn('label: qsTr("5h")', row)
        self.assertIn('label: qsTr("7d")', row)
        self.assertIn('text: modelData.id === "gemini" ? qsTr("Google") : qsTr("Claude/GPT")', row)
        self.assertNotIn('Cached ·', row)

    def test_no_redundant_card_heading(self):
        card = (ROOT / "cards/AgentUsageCard.qml").read_text()
        self.assertNotIn('qsTr("Limits")', card)


if __name__ == "__main__":
    unittest.main()
