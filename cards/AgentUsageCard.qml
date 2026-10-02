import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Plugins
import qs.components
import qs.services
import dcqwqc.agentusage.components
import dcqwqc.agentusage.services as Agents

// The coding agents on this machine and how much of each is left, sized to sit
// beside the CPU card in the dashboard's Performance tab.
StyledRect {
    id: root

    // Injected by the entry point loader
    property SettingsObject settings: null

    readonly property color accent: Colours.palette.m3primary

    // One accent per agent so three rows of the same shape still read apart,
    // in the same order the hero cards use them
    readonly property var accents: ({
        "claude": Colours.palette.m3primary,
        "codex": Colours.palette.m3secondary,
        "antigravity": Colours.palette.m3tertiary
    })

    readonly property var shown: (Agents.AgentUsage.agents ?? []).filter(a => {
        if (!settings)
            return true;
        if (a.id === "claude")
            return settings.showClaude;
        if (a.id === "codex")
            return settings.showCodex;
        if (a.id === "antigravity")
            return settings.showAntigravity;
        return true;
    })

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.extraLarge

    // This card sits inside a centered/scaled dashboard. Its old implicit width
    // followed the current countdown-label widths, so a timer tick could change
    // the dashboard's total width by a pixel or two and visibly nudge the whole
    // panel. Keep the card geometry invariant while live values update.
    implicitWidth: 320
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2

    Binding {
        target: Agents.AgentUsage
        property: "interval"
        value: root.settings?.refreshSeconds ?? 120
        when: !!root.settings
    }

    Binding {
        target: Agents.AgentUsage
        property: "antigravityPool"
        value: root.settings?.antigravityPool ?? "worst"
        when: !!root.settings
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        anchors.topMargin: Tokens.padding.large
        anchors.bottomMargin: Tokens.padding.large

        spacing: Tokens.spacing.medium

        RowLayout {
            id: headerRow

            Layout.fillWidth: true
            Layout.leftMargin: -Tokens.padding.extraSmall
            spacing: Tokens.spacing.small

            AgentMark {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: Tokens.padding.extraSmall

                // Sized off the title beside it, so it tracks the theme's font
                // scale the way the other cards' icons do
                implicitHeight: Math.round(title.implicitHeight * 1.02)
                implicitWidth: implicitHeight
                colour: root.accent
            }

            StyledText {
                id: title

                text: qsTr("Agents")
                font: Tokens.font.title.medium
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: qsTr("Limits")
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        // Keep the repeated agent rows in a real layout container. Giving each
        // repeated row Layout.fillHeight made the parent card report only its
        // header/startup height, so the Performance row could size the card too
        // short and clip the later rows. Natural row heights make the loader's
        // implicitHeight follow the actual rendered content.
        ColumnLayout {
            id: agentsColumn

            Layout.fillWidth: true
            spacing: Tokens.spacing.medium
            visible: root.shown.length > 0

            Repeater {
                model: root.shown

                AgentRow {
                    required property var modelData

                    Layout.fillWidth: true

                    agent: modelData
                    accent: root.accents[modelData.id] ?? root.accent
                }
            }
        }

        // Nothing to lay out until the first poll lands. Keep a small natural
        // placeholder height rather than asking the layout to fill arbitrary
        // remaining space.
        Item {
            Layout.fillWidth: true
            implicitHeight: placeholderText.implicitHeight + Tokens.padding.small * 2
            visible: root.shown.length === 0

            StyledText {
                id: placeholderText
                anchors.centerIn: parent
                text: Agents.AgentUsage.failed ? qsTr("No agent usage available") : qsTr("Collecting data...")
                font: Tokens.font.body.small
                color: Colours.palette.m3outline
            }
        }
    }
}
