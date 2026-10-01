import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// One rolling window of one agent: its name, how full it is, and the bar.
RowLayout {
    id: root

    required property string label
    required property real value
    required property color accent

    readonly property bool known: value >= 0
    // A window this close to its limit is worth reading as a warning. Not the
    // error red -- nothing is broken, it is just nearly spent -- but the
    // palette's maximum contrast against the card, which is near-black on a
    // light theme and stays as emphatic on a dark one.
    readonly property bool critical: known && value >= 0.9
    readonly property color emphasis: Colours.palette.m3inverseSurface

    spacing: Tokens.spacing.small

    StyledText {
        // Countdown strings change every minute (for example 4h 11m -> 4h 10m).
        // Reserve one fixed text cell so proportional glyph widths never move
        // the progress bar, its sibling gauge, or the parent card.
        Layout.minimumWidth: labelMetrics.width
        Layout.preferredWidth: labelMetrics.width
        Layout.maximumWidth: labelMetrics.width
        horizontalAlignment: Text.AlignLeft

        text: root.label
        font: Tokens.font.body.small
        color: Colours.palette.m3onSurfaceVariant
    }

    TextMetrics {
        id: labelMetrics

        font: Tokens.font.body.small
        // Wider than every current reset label (5-hour and weekly windows).
        text: "88h 88m"
    }

    StyledProgressBar {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter

        implicitHeight: Tokens.padding.small
        value: root.known ? Math.min(1, root.value) : 0
        indeterminate: !root.known
        fgColour: root.critical ? root.emphasis : root.accent

        Behavior on value {
            Anim {}
        }
    }

    StyledText {
        // Held at the width of a full reading so the bars do not jump a pixel
        // sideways every time a percentage gains a digit
        Layout.minimumWidth: metrics.width
        Layout.preferredWidth: metrics.width
        Layout.maximumWidth: metrics.width
        horizontalAlignment: Text.AlignRight

        text: root.known ? `${Math.round(root.value * 100)}%` : "–"
        font: Tokens.font.body.builders.small.build()
        color: root.critical ? root.emphasis : Colours.palette.m3onSurface
    }

    TextMetrics {
        id: metrics

        font: Tokens.font.body.small
        text: "100%"
    }
}
