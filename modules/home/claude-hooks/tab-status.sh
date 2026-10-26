#!/usr/bin/env bash
# Claude Code -> terminal tab colour, for kitty and WezTerm.
#
# kitty: `kitten @ set-tab-color` on the tab holding this window, over the remote
# control socket in KITTY_LISTEN_ON (kitty.nix). Alert states paint the tab,
# working/done/clear reset it.
#
# WezTerm: a marker file named <wezterm-pane-id>.<state>, whose content is the
# session's transcript path. wezterm.nix paints the tab for the alert states only
# (permission, waiting) and ignores working/done.
#
# Never the terminal's own escape codes: claude runs hooks with no controlling
# terminal, and writing an escape to claude's pty injects bytes into a fullscreen
# TUI mid-repaint, which can split one of its own escape sequences and leave the
# terminal with a stuck colour state.
#
# Usage: tab-status.sh set|working|done|clear   (reads the event JSON on stdin)
set -u

event="$(cat)"

state=""
case "${1:-}" in
  set)
    case "$(jq -r '.message // empty' <<<"$event" 2>/dev/null)" in
      *permission*) state=permission ;;
      *) state=waiting ;;
    esac
    ;;
  working | done) state="$1" ;;
esac

if [ -n "${KITTY_WINDOW_ID:-}" ] && [ -n "${KITTY_LISTEN_ON:-}" ]; then
  # Same colours as CLAUDE_ALERTS in wezterm.nix
  case "$state" in
    permission) fg="#181926" bg="#ed8796" ;;
    waiting) fg="#181926" bg="#f5a97f" ;;
    *) fg=NONE bg=NONE ;;
  esac
  kitten @ --to "$KITTY_LISTEN_ON" set-tab-color --match "window_id:$KITTY_WINDOW_ID" \
    active_fg="$fg" active_bg="$bg" inactive_fg="$fg" inactive_bg="$bg" >/dev/null 2>&1
fi

if [ -n "${WEZTERM_PANE:-}" ]; then
  dir="${XDG_RUNTIME_DIR:-/tmp}/claude-attention"
  transcript="$(jq -r '.transcript_path // empty' <<<"$event" 2>/dev/null)"
  mkdir -p "$dir" && rm -f "$dir/$WEZTERM_PANE".*
  [ -z "$state" ] || printf '%s\n' "$transcript" >"$dir/$WEZTERM_PANE.$state"
fi
exit 0
