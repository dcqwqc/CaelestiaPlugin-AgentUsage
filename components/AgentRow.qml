import QtQuick
import QtQuick.Layouts
import M3Shapes
import Caelestia.Config
import qs.components
import qs.services
import dcqwqc.agentusage.components

// One agent: its mark on the left, its quota lines beside it. No name -- the
// mark says which agent it is. Antigravity keeps its two independent pools.
RowLayout {
    id: root

    required property var agent
    required property color accent

    readonly property bool isAntigravity: agent?.id === "antigravity"
    readonly property bool available: agent?.available ?? false
    readonly property bool configured: agent?.configured ?? false
    readonly property real fiveHour: available ? (agent.fiveHour ?? -1) : -1
    readonly property real weekly: available ? (agent.weekly ?? -1) : -1
    readonly property real peak: Math.max(fiveHour, weekly)
    readonly property color colour: (available || configured) ? accent : Colours.palette.m3onSurfaceVariant

    property int nowEpoch: Math.floor(Date.now() / 1000)

    // Shared column grid for every agent: [short label | bar | %] [week label | bar | %].
    // The short label cell fits a countdown plus Antigravity's small pool
    // mark, so Claude, Codex and both pools start their bars at the same x.
    readonly property real shortLabelWidth: Math.ceil(countdownMetrics.width + countdownMetrics.height * 0.8 + Tokens.spacing.extraSmall)
    readonly property real weekLabelWidth: Math.ceil(weekMetrics.width)

    // Both gauges start from their natural width and share the spare room
    // equally (stretch 1 each), so both bars in a row are the same length.
    TextMetrics { id: countdownMetrics; font: Tokens.font.body.small; text: "88h 88m" }
    TextMetrics { id: weekMetrics; font: Tokens.font.body.small; text: "88d" }

    function shortResetText(reset: real): string {
        let mins = Math.max(0, Math.ceil((reset - nowEpoch) / 60));
        if (mins < 60)
            return qsTr("%1m").arg(mins);

        const hours = Math.floor(mins / 60);
        mins %= 60;
        return mins > 0 ? qsTr("%1h %2m").arg(hours).arg(mins) : qsTr("%1h").arg(hours);
    }

    function weeklyResetText(reset: real): string {
        return qsTr("%1d").arg(Math.max(0, Math.ceil((reset - nowEpoch) / 86400)));
    }

    spacing: Tokens.spacing.medium

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.nowEpoch = Math.floor(Date.now() / 1000)
    }

    MaterialShape {
        Layout.alignment: Qt.AlignVCenter
        implicitSize: logo.implicitHeight + Tokens.padding.small
        color: root.available ? Colours.palette.m3secondaryContainer
                              : Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
        opacity: (root.available || root.configured) ? 1 : 0.7

        shape: {
            if (root.peak >= 0.8)
                return MaterialShape.SoftBurst;
            if (root.peak >= 0.4)
                return MaterialShape.Sunny;
            return MaterialShape.Cookie4Sided;
        }

        Behavior on color {
            CAnim {}
        }

        AgentLogo {
            id: logo
            anchors.centerIn: parent
            agent: root.agent?.id ?? ""
            colour: root.colour
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: Tokens.spacing.extraSmall
        // A last-known reading stays on screen, just quieter than a live one.
        opacity: (root.agent?.stale ?? false) ? 0.6 : 1

        Behavior on opacity {
            Anim {}
        }

        StyledText {
            visible: !root.available
            text: root.agent?.detail === "Usage rate-limited" ? qsTr("Rate limited") : qsTr("No data")
            font: Tokens.font.body.small
            color: Colours.palette.m3outline
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !root.isAntigravity && root.available
            spacing: Tokens.spacing.medium

            AgentGauge {
                Layout.fillWidth: true
                Layout.horizontalStretchFactor: 1
                labelWidth: root.shortLabelWidth
                label: root.agent?.fiveHourResets > root.nowEpoch
                       ? root.shortResetText(root.agent.fiveHourResets) : qsTr("5h")
                value: root.fiveHour
                accent: root.accent
            }

            AgentGauge {
                Layout.fillWidth: true
                Layout.horizontalStretchFactor: 1
                                labelWidth: root.weekLabelWidth
                label: root.agent?.weeklyResets > root.nowEpoch
                       ? root.weeklyResetText(root.agent.weeklyResets) : qsTr("7d")
                value: root.weekly
                accent: root.accent
            }
        }

        Repeater {
            model: root.isAntigravity && root.available ? (root.agent?.pools ?? []) : []

            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium
                opacity: modelData.stale ? 0.75 : 1

                AgentGauge {
                    Layout.fillWidth: true
                    Layout.horizontalStretchFactor: 1
                    compact: true
                    labelWidth: root.shortLabelWidth
                    // The pool is told apart by its mark; the text is the reset
                    // countdown, as on every other row.
                    mark: modelData.id === "gemini" ? "gemini" : "claude"
                    label: (modelData.fiveHourResets ?? 0) > root.nowEpoch
                           ? root.shortResetText(modelData.fiveHourResets) : qsTr("5h")
                    value: modelData.fiveHour ?? -1
                    accent: root.accent
                }

                AgentGauge {
                    Layout.fillWidth: true
                    Layout.horizontalStretchFactor: 1
                                        compact: true
                    labelWidth: root.weekLabelWidth
                    label: (modelData.weeklyResets ?? 0) > root.nowEpoch
                           ? root.weeklyResetText(modelData.weeklyResets) : qsTr("7d")
                    value: modelData.weekly ?? -1
                    accent: root.accent
                }
            }
        }
    }
}
