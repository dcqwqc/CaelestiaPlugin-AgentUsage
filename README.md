# AgentUsage

Five-hour and weekly **remaining** usage for the coding agents, as a card
in the Caelestia dashboard's Performance tab. 100% means fully available;
0% means the window has been exhausted.

![the card beside the CPU hero card](docs/performance-tab.png)

A window below 10% remaining goes to the palette's maximum contrast against the card
rather than the error red — nothing is broken when an agent is nearly spent,
it just wants looking at.

Every agent bills against the same two rolling windows — a short one and a
week — so all three get the same pair of gauges, sitting beside a blob that
swells as the agent gets used up, the way the CPU card's usage blob does.

| Agent | Where the reading comes from |
|---|---|
| Claude Code | Primarily native statusLine rate-limit data (no network calls); the usage endpoint is a fallback. |
| Codex | Recent observed rate limits in local Codex session logs and, optionally, a trusted SSH host's session logs. |
| Antigravity | `agy -p /usage`, which reads the CLI's quota display without spending a turn. |

Claude Code's native statusLine data is now the preferred source. Install
scripts/claude-statusline-capture as the command in Claude Code's settings.
After a Claude API response, the status line passes 5-hour and weekly quota
percentages directly to the collector without extra network calls. Only quota
percentages, reset times, and measurement time are stored locally; no prompts,
conversation contents, or credentials.

The dashboard keeps the last verified values across restarts and displays
Cached for older readings. If Claude has not yet emitted native quota data,
the legacy usage endpoint may still fail with HTTP 429; its retries are
backed off. Being signed in does not guarantee the usage endpoint works.

An agent that is not installed, not signed in, or has never been run says so
instead of drawing an empty gauge — nothing here reports 0% for "no idea".

Codex only learns its limits when a session receives a quota snapshot. The
collector compares the newest usable local and SSH-host observations and shows
the host and age beside Codex. It never requests a Codex completion, accesses
credentials, or invents a fresh reading. A window whose recorded reset has
passed is **unknown** (dash), not falsely 100% remaining; snapshots older than
three hours are unavailable. Recent null/null quota events are ignored, and
near-simultaneous sessions use the conservative reading for the same reset
window. SSH is read-only, noninteractive and limited to known hosts.

## Requires

A shell carrying Caelestia's plugin loader, and a Performance tab that renders
`custom` entry points asking for the `performance` slot:

```qml
Repeater {
    model: Plugins.entryPoints(EntryPointType.Custom).filter(e => e.properties.slot === "performance")

    EntryPointLoader {
        required property var modelData

        Layout.fillWidth: true
        Layout.fillHeight: true

        entryPoint: modelData
    }
}
```

Both live in [kagami-caelestia](https://github.com/dcqwqc/CaelestiaPlugin-Kagami-caelestia).
The hero cards there give up their stretch while a plugin holds that slot, so
the CPU card's usage blob stays beside the CPU readout instead of being pushed
to the far right of the row.

`python3` for the collector, and `agy` on PATH for the Antigravity row.
Optional remote Codex usage needs key-based `ssh` access to the configured
trusted host. The helper Python source is streamed over SSH; nothing is
installed or modified on the remote machine.

## Install

```sh
git clone https://github.com/dcqwqc/CaelestiaPlugin-AgentUsage \
    ~/.local/share/caelestia/plugins/agent-usage
```

Then enable `dcqwqc/agentusage` on the Plugins page.

## Settings

| Setting | Default | |
|---|---|---|
| Refresh interval | 120s | Claude Code and Antigravity are queried; Codex session logs are read locally and optionally over SSH. |
| Codex usage host | philipedia | SSH host to read Codex logs from; leave blank for local only. |
| Show Claude Code / Codex / Antigravity | on | Hides a row entirely. |

The collector caches to `$XDG_RUNTIME_DIR/caelestia-agent-usage.json` for half
the refresh interval, so several shells on one machine do not each go asking.

## Antigravity

`agy` reports what is **left**, not what is spent, and it bills Gemini apart
from the Claude and GPT models it can also drive — so there is no single
number for it:

```
Gemini Models            Weekly Limit Remaining      5%    2026-09-23T12:14:00Z
Gemini Models            Five Hour Limit Remaining  99%    2026-09-21T20:41:22Z
Claude and GPT models    Weekly Limit Remaining     66%    2026-09-27T19:48:19Z
Claude and GPT models    Five Hour Limit Remaining 100%    2026-09-21T22:37:26Z
```

Antigravity displays **two compact lines** below its title: Google and
Claude/GPT. Each line shows the **5h** and **7d** remaining-allowance bars side by side.
The two pools are never combined into an artificial overall percentage.
Successful readings persist in `~/.cache/caelestia-agent-usage-last-good.json`,
including across restarts. When refreshing fails, the last known value remains
visible with a small **Cached** indicator rather than lengthy error messages.
Antigravity retains cached readings independently for each pool/window; Claude
Code and Codex also retain their last known readings. Unobserved values stay
unknown instead of being reported as zero.

Asking costs about 2.5s of process startup, so the cache matters here more than
for the others.

## Marks

The three marks are drawn as single filled paths so they take the palette like
any other icon. Claude's and OpenAI's are from
[simple-icons](https://github.com/simple-icons/simple-icons) (CC0);
Antigravity's is from [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme)
(GPL-3.0), flattened to its silhouette. Each is a trademark of its owner and is
used here only to label that owner's own service.

## Licence

GPL-3.0.
