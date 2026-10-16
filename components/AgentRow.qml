import QtQuick
import QtQuick.Layouts
import M3Shapes
import Caelestia.Config
import qs.components
import qs.services
import dcqwqc.agentusage.components

// Compact header + quota lines. Antigravity keeps its two independent pools.
ColumnLayout {
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
    // The short label cell fits both a countdown and an Antigravity pool name,
    // so Claude, Codex and both Antigravity pools start their bars at the same x.
    readonly property real shortLabelWidth: Math.ceil(Math.max(countdownMetrics.width, poolMetrics.width))
    readonly property real weekLabelWidth: Math.ceil(weekMetrics.width)

    TextMetrics { id: countdownMetrics; font: Tokens.font.body.small; text: "88h 88m" }
    TextMetrics { id: poolMetrics; font: Tokens.font.body.small; text: "Claude/GPT" }
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

    function observationAge(epoch: real): string {
        if (!epoch) return qsTr("unknown age");
        const minutes = Math.max(0, Math.floor((nowEpoch - epoch) / 60));
        if (minutes < 1) return qsTr("now");
        if (minutes < 60) return qsTr("%1m ago").arg(minutes);
        if (minutes < 2880) return qsTr("%1h ago").arg(Math.floor(minutes / 60));
        return qsTr("%1d ago").arg(Math.floor(minutes / 1440));
    }

    spacing: Tokens.spacing.extraSmall

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.nowEpoch = Math.floor(Date.now() / 1000)
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

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

        StyledText {
            text: root.agent?.name ?? ""
            font: Tokens.font.title.small
            color: root.colour
        }

        Item {
            Layout.fillWidth: true
        }

        // One quiet status on the header, not a tooltip/paragraph per pool.
        StyledText {
            // Only says something when the numbers below are not live.
            visible: !root.available || (root.agent?.stale ?? false)
            text: {
                if (!root.available)
                    return root.agent?.detail === "Usage rate-limited"
                        ? qsTr("Rate limited") : qsTr("No data");
                return root.observationAge(root.agent?.observedAt ?? 0);
            }
            font: Tokens.font.body.small
            color: Colours.palette.m3onSurfaceVariant
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: !root.isAntigravity && root.available
        spacing: Tokens.spacing.small
        opacity: (root.agent?.stale ?? false) ? 0.75 : 1

        AgentGauge {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            labelWidth: root.shortLabelWidth
            label: root.agent?.fiveHourResets > root.nowEpoch
                   ? root.shortResetText(root.agent.fiveHourResets) : qsTr("5h")
            value: root.fiveHour
            accent: root.accent
        }

        AgentGauge {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            labelWidth: root.weekLabelWidth
            label: root.agent?.weeklyResets > root.nowEpoch
                   ? root.weeklyResetText(root.agent.weeklyResets) : qsTr("7d")
            value: root.weekly
            accent: root.accent
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.isAntigravity
        spacing: Tokens.spacing.extraSmall

        Repeater {
            model: root.agent?.pools ?? []

            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                opacity: modelData.stale ? 0.75 : 1

                AgentGauge {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    compact: true
                    labelWidth: root.shortLabelWidth
                    label: modelData.id === "gemini" ? qsTr("Google") : qsTr("Claude/GPT")
                    value: modelData.fiveHour ?? -1
                    accent: root.accent
                }

                AgentGauge {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
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
