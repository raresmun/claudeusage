# ClaudeUsage — Project Brief

You are building ClaudeUsage, a native macOS menu bar app that shows Claude Code session and weekly usage at a glance. Public open-source release, MIT licensed.

## North star

A user opens GitHub, runs one command, and 60 seconds later has a menu bar icon showing their Claude Code 5-hour and weekly usage with live updates. They never think about it again. It uses no network, no tokens, no battery to speak of, and the source is short enough that a stranger can read it in 15 minutes and trust it.

## Non-negotiables

1. Zero network. No `URLSession`, no analytics, no update checks, no telemetry. The app's entitlements file must omit `com.apple.security.network.client` entirely. This is the trust story.
2. Read-only filesystem access to `~/.claude/` only. Sandboxed.
3. Launch at login via `SMAppService.mainApp` (macOS 13+). Toggle exposed in the dropdown menu and reflected in System Settings → Login Items.
4. Native, lightweight. SwiftUI `MenuBarExtra`. Idle RAM target: < 30 MB. CPU between refreshes: 0%.
5. macOS 13 Ventura minimum. Don't pull in compatibility shims for older versions.
6. No third-party dependencies. Pure Swift + system frameworks.

## Coding philosophy

- Think before coding. Sketch the data flow first.
- Simplicity wins. If a section needs a comment to explain "why", consider rewriting.
- Surgical changes. Change one thing per commit.
- Verifiable success criteria. Each task should have a way to confirm it works.
- Never let tests adapt to the app.

## Data sources

Both live under `~/.claude/`. Read only.

### `~/.claude/statusline.jsonl`

Periodic snapshots written by Claude Code. Each line is JSON. We want the last valid line. Use a tail-read (seek to end, read last ~16 KB, split on newline, parse from the bottom).

Expected fields (be defensive — names may vary):

- `timestamp` — ISO 8601
- `cost_usd` — number
- `model` — string
- `rate_limit.five_hour.used_pct` — number 0–100
- `rate_limit.five_hour.resets_at` — ISO 8601
- `rate_limit.weekly.used_pct` — number 0–100
- `rate_limit.weekly.resets_at` — ISO 8601

If the file doesn't exist or is empty: show "—" placeholders. Don't crash.

### `~/.claude/projects/**/*.jsonl`

One file per session. Each line has `timestamp` and (on assistant messages) `message.usage` with `input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`.

We use this for:

- Active 5h block tokens: sum tokens from lines with timestamps within the last 5 hours
- Today's tokens: sum tokens from lines with timestamps today (local timezone)

Performance: only open files whose `mtime` is within the last ~6 hours for the 5h block, last ~36 hours for today.

## File layout

```
ClaudeUsage/
├── ClaudeUsage.xcodeproj/
├── ClaudeUsage/
│   ├── ClaudeUsageApp.swift       # @main, MenuBarExtra
│   ├── Views/
│   │   ├── MenuBarLabel.swift     # The compact menu bar text
│   │   ├── DropdownView.swift     # The full menu
│   │   ├── ProgressBar.swift      # Unicode block bar
│   │   └── AboutView.swift
│   ├── Models/
│   │   ├── UsageSnapshot.swift    # The struct we display
│   │   ├── StatuslineReader.swift # Tails statusline.jsonl
│   │   ├── ProjectsReader.swift   # Walks projects/**/*.jsonl
│   │   └── UsageStore.swift       # ObservableObject, owns the timer
│   ├── Services/
│   │   └── LaunchAtLogin.swift    # SMAppService wrapper
│   ├── Resources/
│   │   ├── Assets.xcassets/       # App icon
│   │   └── Info.plist             # LSUIElement = true
│   └── ClaudeUsage.entitlements
├── .github/workflows/release.yml
├── scripts/build.sh
├── scripts/make-dmg.sh
├── README.md
├── LICENSE
└── CLAUDE.md
```

## Required GitHub Secrets

- `APPLE_CERTIFICATE_P12_BASE64` — base64-encoded Developer ID Application cert (.p12)
- `APPLE_CERTIFICATE_PASSWORD` — password for the .p12
- `APPLE_ID` — Apple ID email
- `APPLE_APP_PASSWORD` — app-specific password from appleid.apple.com
- `APPLE_TEAM_ID` — 10-character Team ID

## Definition of done for v1

- [ ] App launches, shows live 5h + weekly % in menu bar
- [ ] Click reveals dropdown with all sections specified
- [ ] "Launch at login" toggle works and survives reboot
- [ ] Idle RAM under 30 MB (verified with Activity Monitor)
- [ ] No network entitlement (verified by reading the `.entitlements` file)
- [ ] `git clone && ./scripts/build.sh` produces a working `.app` on a clean machine
- [ ] Pushing `git tag v0.1.0 && git push --tags` produces a notarized DMG in a GitHub release
- [ ] README has a screenshot and the privacy section is unambiguous
- [ ] Repo public at github.com/raresmun/claudeusage with MIT license
