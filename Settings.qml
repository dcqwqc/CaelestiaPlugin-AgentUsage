import Caelestia.Plugins

SettingsObject {
    property int refreshSeconds: 120
    SettingMeta on refreshSeconds {
        label: "Refresh interval"
        description: "Seconds between usage polls. Each agent is refreshed independently; last verified readings survive failures."
        icon: "update"
        inputType: SettingMeta.SpinBox
        min: 30
        max: 900
        step: 30
    }

    property bool markCalendarResets: true
    SettingMeta on markCalendarResets {
        label: "Mark calendar resets"
        description: "Mark dates on the calendar where an agent usage limit resets."
        icon: "calendar_today"
        inputType: SettingMeta.Switch
    }

    property bool showClaude: true
    SettingMeta on showClaude {
        label: "Show Claude Code"
        description: "Reads the usage endpoint with the credentials Claude Code already stores."
        icon: "smart_toy"
        inputType: SettingMeta.Switch
    }

    // Optional SSH host where Codex is actually running. Empty = local only.
    property string codexHost: "philipedia"
    SettingMeta on codexHost {
        label: "Codex usage host"
        description: "Read recent quota snapshots from this trusted SSH host as well as locally. Leave empty for local only."
        icon: "computer"
        inputType: SettingMeta.TextField
    }

    property bool showCodex: true
    SettingMeta on showCodex {
        label: "Show Codex"
        description: "Reads the rate limits recorded in the newest Codex session log."
        icon: "terminal"
        inputType: SettingMeta.Switch
    }

    property bool showAntigravity: true
    SettingMeta on showAntigravity {
        label: "Show Antigravity"
        description: "Shows Google/Gemini and Claude/GPT quotas separately, including last verified readings."
        icon: "rocket_launch"
        inputType: SettingMeta.Switch
    }

}
