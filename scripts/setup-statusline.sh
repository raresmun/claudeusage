#!/usr/bin/env bash
# scripts/setup-statusline.sh
#
# Claude Code doesn't write the file ClaudeUsage reads. Instead, it pipes a
# JSON snapshot (with rate_limits, cost, model, context window) to a statusline
# shell script on every prompt. This script patches ~/.claude/statusline.sh so
# it also persists that JSON to ~/.claude/statusline.jsonl — the file the
# menu bar app reads. Idempotent. Makes a timestamped backup before editing.
set -euo pipefail

STATUSLINE="$HOME/.claude/statusline.sh"
MARKER="# claudeusage: persist statusline snapshot"

if [[ ! -d "$HOME/.claude" ]]; then
  echo "Error: ~/.claude/ doesn't exist. Is Claude Code installed?" >&2
  exit 1
fi

if [[ ! -f "$STATUSLINE" ]]; then
  cat >&2 <<'EOF'
Error: ~/.claude/statusline.sh doesn't exist.

You don't have a custom Claude Code statusline yet. ClaudeUsage gets its
rate-limit data from the JSON Claude Code pipes to its statusline command,
so you need to set one up first.

  1. Create ~/.claude/statusline.sh:

         #!/bin/bash
         input=$(cat)
         { printf '%s\n' "$input" > "$HOME/.claude/statusline.jsonl.tmp" \
             && mv "$HOME/.claude/statusline.jsonl.tmp" \
                   "$HOME/.claude/statusline.jsonl"; } 2>/dev/null

     Then: chmod +x ~/.claude/statusline.sh

  2. Tell Claude Code to use it — add to ~/.claude/settings.json:

         { "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" } }

  3. Restart Claude Code, then re-run this script (it'll just confirm and exit).

EOF
  exit 1
fi

if grep -qF 'statusline.jsonl.tmp' "$STATUSLINE"; then
  echo "Already writes to ~/.claude/statusline.jsonl. Nothing to do."
  exit 0
fi

if ! grep -qF 'input=$(cat)' "$STATUSLINE"; then
  cat >&2 <<'EOF'
Error: ~/.claude/statusline.sh uses a different pattern than expected.

This script looks for the literal line `input=$(cat)` and inserts the
snapshot-dump after it. Your script reads stdin differently. Add this
snippet manually right after the line that captures stdin into a variable:

    # claudeusage: persist statusline snapshot
    { printf '%s\n' "$input" > "$HOME/.claude/statusline.jsonl.tmp" \
        && mv "$HOME/.claude/statusline.jsonl.tmp" \
              "$HOME/.claude/statusline.jsonl"; } 2>/dev/null

(Replace `$input` with whatever variable your script uses.)

EOF
  exit 1
fi

BACKUP="$STATUSLINE.bak.$(date +%Y%m%d%H%M%S)"
cp "$STATUSLINE" "$BACKUP"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

inserted=0
while IFS= read -r line || [[ -n "$line" ]]; do
  printf '%s\n' "$line"
  if [[ $inserted -eq 0 && "$line" == 'input=$(cat)' ]]; then
    cat <<'PATCH'

# claudeusage: persist statusline snapshot
{ printf '%s\n' "$input" > "$HOME/.claude/statusline.jsonl.tmp" && mv "$HOME/.claude/statusline.jsonl.tmp" "$HOME/.claude/statusline.jsonl"; } 2>/dev/null
PATCH
    inserted=1
  fi
done < "$STATUSLINE" > "$TMP"

mv "$TMP" "$STATUSLINE"
trap - EXIT
chmod +x "$STATUSLINE"

echo "Patched ~/.claude/statusline.sh"
echo "Backup saved to: $BACKUP"
echo "Next Claude Code prompt will populate ~/.claude/statusline.jsonl."
