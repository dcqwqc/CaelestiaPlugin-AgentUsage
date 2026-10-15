pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The usage limits of every coding agent on this machine, refreshed on a
// timer. One collector script answers for all of them, so a poll is a single
// process rather than one per agent.
Singleton {
    id: root

    readonly property string script: `${Quickshell.env("HOME")}/.local/share/caelestia/plugins/agent-usage/scripts/agent-usage`

    // Seconds between polls. The card binds this from the plugin settings.
    property int interval: 120
    property var agents: []
    property bool ready: false
    property bool failed: false
    readonly property bool busy: proc.running

    function refresh(): void {
        if (!proc.running)
            proc.running = true;
    }

    // A poll never costs more than the cache allows, so a refresh forced by a
    // card appearing cannot hammer the endpoints behind it.
    onIntervalChanged: timer.restart()

    Process {
        id: proc

        command: [root.script, "--max-age", Math.max(15, Math.round(root.interval / 2)).toString()]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.agents = JSON.parse(text).agents ?? [];
                    root.failed = false;
                } catch (e) {
                    root.failed = true;
                }
                root.ready = true;
            }
        }

        onExited: code => {
            if (code !== 0) {
                root.failed = true;
                root.ready = true;
            }
        }
    }

    Timer {
        id: timer

        interval: root.interval * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
