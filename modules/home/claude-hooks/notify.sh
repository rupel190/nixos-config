#!/usr/bin/env bash
# Claude Code Notification hook.
#
# Fires a swaync popup branded as Claude whose SUMMARY is this session's kitty or
# WezTerm tab/task title (so with several sessions open you can tell which one
# wants you) and whose BODY is the reason (e.g. "Claude needs your permission to
# use Bash").
#
# The event JSON arrives on stdin; $KITTY_WINDOW_ID / $WEZTERM_PANE are inherited
# from the `claude` process running in this pane. Fire-and-forget — no click handling.
set -u

ICON="/home/rupel/.local/share/icons/claude-code.png"

msg="$(jq -r '.message // empty')"

pane=""
title=""
proj=""
rec=""
if [ -n "${KITTY_WINDOW_ID:-}" ] && [ -n "${KITTY_LISTEN_ON:-}" ] && command -v kitten >/dev/null 2>&1; then
  pane="kitty-$KITTY_WINDOW_ID"
  rec="$(kitten @ --to "$KITTY_LISTEN_ON" ls --match "id:$KITTY_WINDOW_ID" 2>/dev/null \
    | jq -r 'first(.[].tabs[].windows[]) | "\(.title)\t\(.cwd)"')"
elif [ -n "${WEZTERM_PANE:-}" ] && command -v wezterm >/dev/null 2>&1; then
  pane="$WEZTERM_PANE"
  rec="$(wezterm cli list --format json 2>/dev/null \
    | jq -r --argjson p "$pane" '.[] | select(.pane_id==$p) | "\(.title)\t\(.cwd)"')"
fi
if [ -n "$rec" ]; then
  title="${rec%%$'\t'*}"
  cwd="${rec#*$'\t'}"
  # Strip Claude's leading spinner glyph / whitespace from the title.
  title="$(printf '%s' "$title" | sed 's/^[^[:alnum:]]*//')"
  [ -n "$cwd" ] && proj="$(basename "$cwd")"
fi

# Which session this is: title -> "Claude Code · <project>" -> "Claude Code".
session="$title"
[ -z "$session" ] && session="Claude Code${proj:+ · $proj}"

# The reason; guard so the bold summary line is never empty.
reason="$msg"
[ -z "$reason" ] && reason="Claude needs your attention"

# Per-pane replace tag: a session collapses its OWN repeat popups, but different
# sessions coexist instead of overwriting each other.
tag="claude-code${pane:+-$pane}"

# swaync truncates the SUMMARY (bold, single line) but wraps the BODY. So the
# short, predictable reason is the summary; the longer session title is the body,
# where it has room to wrap instead of getting cut off.
notify-send \
  -a "Claude Code" \
  -i "$ICON" \
  -h "string:x-canonical-private-synchronous:$tag" \
  "$reason" "$session"
