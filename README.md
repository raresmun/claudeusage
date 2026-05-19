# ClaudeUsage

A small macOS menu bar app showing Claude Code 5-hour and weekly rate-limit usage at a glance. Lives in your status bar, refreshes every 30 seconds, never touches the network.

<!-- Screenshot lives in docs/screenshot.png. Replace with a real capture before sharing widely. -->
![ClaudeUsage in the menu bar](docs/screenshot.png)

The menu bar shows a gauge icon plus two percentages: `5h X% · wk Y%`. The icon and text color track the worst of the two: green under 35%, yellow under 60%, orange under 85%, red beyond. Click for the full dropdown: active 5-hour block tokens, today's tokens, model in use, session cost, and reset times.

## Why

- **Zero network.** No analytics, no update checks, no telemetry. The entitlements file omits every `com.apple.security.network.*` key — there is no way for the app to reach the internet.
- **Sandboxed in shipped builds.** Read-only access to `~/.claude/` only.
- **Short source.** Under 700 lines of Swift. A stranger can read the whole thing in 15 minutes.

## Setup

### Requirements

- macOS 13 Ventura or later
- Claude Code already installed and signed in (the app reads `~/.claude/`)
- **Xcode 15 or later**, installed from the [Mac App Store](https://apps.apple.com/app/xcode/id497799835). Command Line Tools alone are **not** enough — `scripts/build.sh` calls `xcodebuild`, which requires the full Xcode IDE. After installing, run `sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer` once so the toolchain resolves.

### 1. Clone the repo

```sh
git clone https://github.com/raresmun/claudeusage
cd claudeusage
```

### 2. Wire up the Claude Code statusline

```sh
./scripts/setup-statusline.sh
```

Claude Code does not write rate-limit data to disk on its own — it pipes a JSON snapshot to a *statusline script* on every prompt. This one-time script appends a snippet to `~/.claude/statusline.sh` that also persists each snapshot to `~/.claude/statusline.jsonl`, the file ClaudeUsage tail-reads. It is idempotent and makes a timestamped backup before editing.

If you don't have a custom statusline yet, the script prints the exact 3-step recipe to create one and exits without modifying anything. Follow the printed instructions, then re-run the script.

You can skip this step — the menu bar will show `—` instead of percentages but will still show today's tokens and the active 5-hour block tokens read directly from `~/.claude/projects/`.

### 3. Build the app

```sh
./scripts/build.sh
```

Produces an ad-hoc-signed `ClaudeUsage.app` under `build/DerivedData/Build/Products/Release/`. First builds can take a minute or two while Xcode downloads platform metadata.

### 4. Install and launch

```sh
cp -R build/DerivedData/Build/Products/Release/ClaudeUsage.app /Applications/
open /Applications/ClaudeUsage.app
```

A gauge icon will appear in the menu bar with `5h X% · wk Y%` next to it (or `—` placeholders until Claude Code writes its first snapshot — open a Claude Code session and send one prompt to populate the data).

### 5. (Optional) Launch at login

Click the menu bar icon → toggle **Launch at login**. The toggle uses `SMAppService.mainApp` and is reflected in **System Settings → General → Login Items**.

## How it works

ClaudeUsage reads two paths under `~/.claude/`, both read-only:

- **`~/.claude/statusline.jsonl`** — written by your statusline command (after running `scripts/setup-statusline.sh`). ClaudeUsage tail-reads the last valid JSON line to pull out `rate_limits.five_hour.used_percentage`, `rate_limits.seven_day.used_percentage`, their `resets_at` timestamps, `cost.total_cost_usd`, and `model.display_name`.
- **`~/.claude/projects/**/*.jsonl`** — one file per Claude Code session. ClaudeUsage walks these, filtered by recent modification time, to sum tokens for today's totals and the active 5-hour block. The 5-hour block uses the server-provided `resets_at` timestamp to determine the exact block boundary (`resets_at − 5h`), so the token count matches what Claude Code reports internally rather than using a rolling window.

The app refreshes every 30 seconds, and again the moment you open the dropdown. It pauses the timer during system sleep and resumes on wake.

## Privacy

The trust story:

- The entitlements file ([`ClaudeUsage/ClaudeUsage.entitlements`](ClaudeUsage/ClaudeUsage.entitlements)) declares the sandbox and a read-only temporary exception for `~/.claude/`. No `com.apple.security.network.*` keys.
- The source is small enough to audit ([`ClaudeUsage/`](ClaudeUsage/)).

Caveats worth knowing about:

- A **locally-built** `./scripts/build.sh` artifact is ad-hoc signed and runs unsandboxed — Apple won't honor the temporary-exception entitlement without a Developer ID. The privacy claim above is about the **notarized release build** (when one exists). The source you ran is the same; the sandbox is just absent locally.
- The setup script modifies one file under `~/.claude/`. That's it. No other writes.

## Status

This is v0.1 and a few things from the original plan are still pending:

- **No notarized DMG release yet.** The `.github/workflows/release.yml` pipeline is wired up but has never been exercised end-to-end — it requires an Apple Developer cert and five GitHub secrets (see `CLAUDE.md`).
- **No Homebrew cask yet.**
- **No app icon yet.** The Assets catalog is wired up but contains no PNGs.
- **RAM is ~90 MB**, not the <30 MB target in the brief. SwiftUI `MenuBarExtra` carries significant overhead; hitting that target would mean rewriting against `NSStatusItem`.
- **Tested only on macOS 26 (Apple Silicon).** The minimum is macOS 13 Ventura but I haven't verified the menu bar label color rendering there.

## Roadmap

- Notification when approaching a rate limit
- Per-project token breakdown
- The Status items above

## License

MIT — see [LICENSE](LICENSE).
