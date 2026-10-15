import QtQuick
import QtQuick.Layouts
import M3Shapes
import Caelestia.Config
import qs.components
import qs.services
import dcqwqc.agentusage.components

// One agent: its mark in a blob that swells with how much of the agent has
// been spent, then the two windows it is billed against.
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
    // Keep the labels counting down between usage polls as well.
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
        // A week label is deliberately days-only: it replaces WEEK without
        // widening the card and answers the useful long-window question.
        return qsTr("%1d").arg(Math.max(0, Math.ceil((reset - nowEpoch) / 86400)));
    }

    function cacheAge(observedAt: real): string {
        if (observedAt <= 0)
            return qsTr("Cached");
        const seconds = Math.max(0, nowEpoch - observedAt);
        if (seconds < 120)
            return qsTr("Cached · 1m");
        if (seconds < 3600)
            return qsTr("Cached · %1m").arg(Math.floor(seconds / 60));
        if (seconds < 86400)
            return qsTr("Cached · %1h").arg(Math.floor(seconds / 3600));
        return qsTr("Cached · %1d").arg(Math.floor(seconds / 86400));
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.nowEpoch = Math.floor(Date.now() / 1000)
    }

    spacing: Tokens.spacing.medium

    MaterialShape {
        Layout.alignment: Qt.AlignVCenter

        implicitSize: logo.implicitHeight + Tokens.padding.large
        color: root.available ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
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
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                text: root.agent?.name ?? ""
                font: Tokens.font.title.small
                color: root.colour
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                visible: !root.isAntigravity && root.available && (root.agent?.stale ?? false)
                text: root.cacheAge(root.agent?.observedAt ?? 0)
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                visible: !root.available && text.length > 0
                text: root.agent?.detail ?? ""
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.large
            visible: root.available && !root.isAntigravity

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

        // Antigravity has two *independent* quota pools; do not combine their
        // 5-hour or weekly limits into an artificial worst-case reading.
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.isAntigravity
            spacing: Tokens.spacing.small

            Repeater {
                model: root.agent?.pools ?? []

                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        StyledText {
                            text: modelData.name
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        StyledText {
                            visible: modelData.stale && modelData.available
                            text: root.cacheAge(modelData.observedAt ?? 0)
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.large

                        AgentGauge {
                            Layout.fillWidth: true
                            label: modelData.fiveHourResets > root.nowEpoch
                                ? root.shortResetText(modelData.fiveHourResets) : qsTr("5H")
                            value: modelData.fiveHour ?? -1
                            accent: root.accent
                        }

                        AgentGauge {
                            Layout.fillWidth: true
                            label: modelData.weeklyResets > root.nowEpoch
                                ? root.weeklyResetText(modelData.weeklyResets) : qsTr("WEEK")
                            value: modelData.weekly ?? -1
                            accent: root.accent
                        }
                    }
                }
            }
        }

        // Keeps an unavailable agent the same height as an available one, so
        // the three rows stay on a grid however many are signed in
        Item {
            Layout.fillWidth: true
            visible: !root.available && !root.isAntigravity
            implicitHeight: Tokens.padding.small
        }
    }
}
