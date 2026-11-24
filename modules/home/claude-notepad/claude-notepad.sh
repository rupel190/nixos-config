# Claude Code's Ctrl+G inside herdr: nvim in a split under the chat, Claude goes on at once.
# The name must keep "notepad": Claude then takes it for a desktop editor and leaves its screen up.
# The same key is the way back: nvim writes its text to outbox and presses Ctrl+G in Claude.
file="${*: -1}"

# Claude's tools (a git commit) and terminals outside herdr get nvim itself
if [ -n "${CLAUDECODE:-}" ] || [ -z "${HC_TERMINAL_ID:-}" ]; then
  exec nvim "$@"
fi

pane() {
  herdr-app ls | jq -r --arg t "$HC_TERMINAL_ID" '[.. | objects | select(.terminal? == $t) | .pane][0] // empty'
}

# split PANE ARGV...: a program in a new pane under PANE, with the keyboard
split() {
  herdr-app 'do' pane.split "$(jq -nc '{direction: "down", pane: $ARGS.positional[0], argv: $ARGS.positional[1:]}' --args -- "$@")" >/dev/null
}

case "${file##*/}" in
  claude-prompt-*.md) ;;
  *)
    # CLAUDE.md, a plan: Claude waits for the second, and starts the first without a terminal
    if [ -t 0 ]; then exec nvim "$@"; fi
    split "$(pane)" nvim "$file"
    exit
    ;;
esac

dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-notepad/$HC_TERMINAL_ID"
mkdir -p "$dir"

# The image placeholders in FILE
images() {
  grep -oE '\[Image #[0-9]+\]' "$1" || true
}

if [ -e "$dir/outbox" ]; then
  # What was put into Claude's own prompt is not lost: its pictures go along, its text goes to nvim.
  # A placeholder nvim had and no longer has was deleted there
  added=$(images "$file" | grep -vxFf <(images "$dir/outbox"; cat "$dir/known") | paste -sd' ' || true)
  sed -E 's/\[Image #[0-9]+\] ?//g' "$file" >"$dir/leftover"
  { cat "$dir/outbox"; [ -z "$added" ] || printf '\n\n%s' "$added"; } >"$file"
  rm "$dir/outbox"
  exit
fi

# Not in a herdr-app pane (hc attach): nvim itself
pane=$(pane)
[ -n "$pane" ] || exec nvim "$@"

# The draft moves to nvim. Image placeholders also stay behind: Claude drops a picture without one
cp "$file" "$dir/incoming"
images "$dir/incoming" | paste -sd' ' | tr -d '\n' >"$file"

if [ -S "$dir/sock" ] && [ "$(nvim --headless --server "$dir/sock" --remote-expr 'v:lua.ClaudeNotepad.take()' </dev/null 2>/dev/null)" = ok ]; then
  herdr-app 'do' pane.focus --terminal "$(cat "$dir/term")" >/dev/null
  exit
fi

rm -f "$dir/sock"
find "$dir/pictures" -type f -mtime +7 -delete 2>/dev/null || true

# herdr splits in half; the border goes to its place in the same breath (notepad.lua keeps it there).
# lost: the rows a second pane's frame takes, as notepad.lua last saw it
rows=$(hc get "$HC_TERMINAL_ID" --json | jq .rows)
lost=$(cat "$dir/../lost" 2>/dev/null || echo 4)
lines=$(cat "$dir/draft" "$dir/incoming" 2>/dev/null | grep -c '' || true)
resize=$(herdr-app status | jq -c --arg pane "$pane" --argjson rows "$rows" --argjson lost "$lost" --argjson lines "$lines" '
  (($rows - $lost) / 2) as $half
  | {direction: "down", pane: $pane, px: (($half - ([2, ([$lines, 20, $half] | min)] | max)) * 1.3 * .font_size / .zoom)}')

split "$pane" env "CLAUDE_NOTEPAD_DIR=$dir" "CLAUDE_NOTEPAD_TERM=$HC_TERMINAL_ID" "CLAUDE_NOTEPAD_ROWS=$rows" \
  nvim --listen "$dir/sock" -c "luafile $NOTEPAD_LUA" "$dir/draft"
herdr-app 'do' pane.resize "$resize" >/dev/null || true
