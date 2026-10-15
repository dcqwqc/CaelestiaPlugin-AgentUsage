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
            visible: !root.available || (root.agent?.stale ?? false)
            text: !root.available ? qsTr("No data") : qsTr("Cached")
            font: Tokens.font.body.small
            color: Colours.palette.m3onSurfaceVariant
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: !root.isAntigravity && root.available
        spacing: Tokens.spacing.small

        AgentGauge {
            Layout.fillWidth: true
            label: root.agent?.fiveHourResets > root.nowEpoch
                   ? root.shortResetText(root.agent.fiveHourResets) : qsTr("5H")
            value: root.fiveHour
            accent: root.accent
        }

        AgentGauge {
            Layout.fillWidth: true
            label: root.agent?.weeklyResets > root.nowEpoch
                   ? root.weeklyResetText(root.agent.weeklyResets) : qsTr("WEEK")
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

                StyledText {
                    Layout.minimumWidth: poolNameMetrics.width
                    Layout.preferredWidth: poolNameMetrics.width
                    Layout.maximumWidth: poolNameMetrics.width
                    text: modelData.id === "gemini" ? qsTr("Google") : qsTr("Claude/GPT")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }

                TextMetrics {
                    id: poolNameMetrics
                    font: Tokens.font.body.small
                    text: "Claude/GPT"
                }

                AgentGauge {
                    Layout.fillWidth: true
                    compact: true
                    label: qsTr("5h")
                    value: modelData.fiveHour ?? -1
                    accent: root.accent
                }

                AgentGauge {
                    Layout.fillWidth: true
                    compact: true
                    label: qsTr("7d")
                    value: modelData.weekly ?? -1
                    accent: root.accent
                }
            }
        }
    }
}
