#!/usr/bin/env bash
# Claude Code -> WezTerm tab colour.
#
# Publishes this session's "wants your attention" state as a marker file named
# <wezterm-pane-id>.<permission|waiting>; wezterm.nix reads the directory when it
# draws the tab bar and paints the whole tab chip red/peach, so a backgrounded
# session is visible at a glance.
#
# A file, deliberately: claude runs hooks with no controlling terminal, and the
# alternative -- writing the OSC 1337 SetUserVar escape to claude's pty -- injects
# bytes into a fullscreen TUI mid-repaint, which can split one of its own escape
# sequences and leave the terminal with a stuck colour state.
#
# Usage: wezterm-status.sh set|clear     (set reads the event JSON on stdin)
set -u

[ -n "${WEZTERM_PANE:-}" ] || exit 0
dir="${XDG_RUNTIME_DIR:-/tmp}/claude-attention"

case "${1:-}" in
  set)
    case "$(jq -r '.message // empty' 2>/dev/null)" in
      *permission*) status="permission" ;;
      *) status="waiting" ;;
    esac
    mkdir -p "$dir" && rm -f "$dir/$WEZTERM_PANE".* && : >"$dir/$WEZTERM_PANE.$status"
    ;;
  clear) rm -f "$dir/$WEZTERM_PANE".* ;;
esac
