#!/usr/bin/env bash
# Claude Code -> WezTerm tab colour, and the state `drovr` waits on.
#
# Publishes this session's state as a marker file named <wezterm-pane-id>.<state>,
# whose content is the session's transcript path. wezterm.nix paints the tab for
# the alert states only (permission, waiting) and ignores working/done; `drovr`
# reads all four, and pulls the final answer from the transcript.
#
# A file, deliberately: claude runs hooks with no controlling terminal, and the
# alternative -- writing the OSC 1337 SetUserVar escape to claude's pty -- injects
# bytes into a fullscreen TUI mid-repaint, which can split one of its own escape
# sequences and leave the terminal with a stuck colour state.
#
# Usage: wezterm-status.sh set|working|done|clear   (reads the event JSON on stdin)
set -u

[ -n "${WEZTERM_PANE:-}" ] || exit 0
dir="${XDG_RUNTIME_DIR:-/tmp}/claude-attention"

event="$(cat)"
transcript="$(jq -r '.transcript_path // empty' <<<"$event" 2>/dev/null)"

publish() {
  mkdir -p "$dir" && rm -f "$dir/$WEZTERM_PANE".* &&
    printf '%s\n' "$transcript" >"$dir/$WEZTERM_PANE.$1"
}

case "${1:-}" in
  set)
    case "$(jq -r '.message // empty' <<<"$event" 2>/dev/null)" in
      *permission*) publish permission ;;
      *) publish waiting ;;
    esac
    ;;
  working | done) publish "$1" ;;
  clear) rm -f "$dir/$WEZTERM_PANE".* ;;
esac
