#!/usr/bin/env bash
# Read the Wayland clipboard aloud via speech-dispatcher — a read-along aid for
# dense prose (select a paragraph, copy, press the bind, read while it speaks).
#
# Toggle semantics: pressing the bind while it is speaking STOPS it. Press again
# to read whatever is on the clipboard now. One key, no separate stop bind.
#
# The real work is _speakable(): terminal/markdown prose is full of things a TTS
# engine reads as gibberish — box-drawing rules, emoji, fenced code, file paths.
# Stripping those is what makes the difference between usable and unbearable.
#
# Three backends. kokoro (82M, warm daemon) is the default and the most natural;
# piper is the fast local fallback; speech-dispatcher (espeak/pico) needs no model
# download at all — always available, always sounds like it.
#
# Usage:
#   say-clip                 # speak clipboard, or stop if already speaking
#   say-clip --stop          # stop unconditionally
#   say-clip --dry           # print the cleaned text instead of speaking it
#   say-clip --voices        # list available voices for the active backend
#   say-clip --demo          # speak the clipboard once per installed voice
#
# Tuning (env):
#   SAY_BACKEND=auto         # auto | kokoro | piper | spd
#   SAY_KOKORO_VOICE=bf_emma # kokoro voice (b* = British, a* = American)
#   SAY_KOKORO_LANG=b        # must match the voice's first letter
#   SAY_KOKORO_IDLE=600      # daemon exits after this many idle seconds
#   SAY_PIPER_VOICE=en_GB-jenny_dioco-medium
#   SAY_VOICES_DIR=~/.local/share/piper-voices
#   SAY_SPEED=1.4            # piper: >1 faster, <1 slower
#   SAY_NOISE_W=             # piper: phoneme-DURATION variance, model default
#                            # 0.8. Measured: 0.0 gives byte-identical output
#                            # every run, 0.8 scatters. So it steadies rhythm
#                            # (less sing-song), it does NOT change timbre —
#                            # brightness/sibilance is a voice+tier choice.
#   SAY_RATE=0               # spd only: -100..100
#   SAY_MODULE=              # spd only: output module, e.g. pico
#   SAY_VOICE=               # spd only: voice type, e.g. male1
#   SAY_MAXCHARS=20000       # guard against accidentally copying a whole file
#   SAY_QUIET=0              # 1 = no hyprctl toasts
set -euo pipefail

BACKEND="${SAY_BACKEND:-auto}"
VOICES_DIR="${SAY_VOICES_DIR:-$HOME/.local/share/piper-voices}"
PIPER_VOICE="${SAY_PIPER_VOICE:-en_GB-jenny_dioco-medium}"
KOKORO_VOICE="${SAY_KOKORO_VOICE:-bf_emma}"
KOKORO_LANG="${SAY_KOKORO_LANG:-b}"
# Kokoro ships voices as named packs, not files; first letter must match the lang.
KOKORO_VOICES=(bf_alice bf_emma bf_isabella bf_lily bm_daniel bm_fable bm_george bm_lewis
               af_heart af_bella af_nicole af_sarah am_michael am_adam am_fenrir am_puck)
SPEED="${SAY_SPEED:-1.4}"
NOISE_W="${SAY_NOISE_W:-}"
RATE="${SAY_RATE:-0}"
MODULE="${SAY_MODULE:-}"
VOICE="${SAY_VOICE:-}"
MAXCHARS="${SAY_MAXCHARS:-20000}"
QUIET="${SAY_QUIET:-0}"

STATE="${XDG_RUNTIME_DIR:-/tmp}/say-clip.speaking"
MODEL="$VOICES_DIR/$PIPER_VOICE.onnx"

# Resolve piper by CAPABILITY, not by name: nixpkgs `piper` is the libratbag
# mouse GUI, and it silently shadowed piper-tts here for two weeks in Aug 2026.
_find_piper() {
  local c
  for c in "${SAY_PIPER_BIN:-}" piper-tts piper; do
    [ -n "$c" ] || continue
    command -v "$c" >/dev/null 2>&1 || continue
    if "$c" --help 2>&1 | grep -q -- '--output-raw'; then PIPER=("$c"); return 0; fi
  done
  PIPER=(nix shell nixpkgs#piper-tts -c piper)
}
_find_piper

# NB: an `a && b || c` one-liner here would return non-zero when BACKEND isn't
# "auto", and `set -e` would kill the script before it ever spoke.
if [ "$BACKEND" = "auto" ]; then
  if command -v kokoro-say >/dev/null 2>&1; then BACKEND=kokoro
  elif [ -f "$MODEL" ]; then BACKEND=piper
  else BACKEND=spd; fi
fi

toast() {
  [ "$QUIET" = "1" ] && return 0
  # Matches the screenshot binds' feedback style; 1 = info, colour is Catppuccin green.
  hyprctl notify 1 1500 "rgb(a6da95)" "$1" >/dev/null 2>&1 || true
}

stop() {
  # piper runs in its own session, so one process-group signal takes down both
  # piper and the player. spd-say has its own stop verb; calling it when nothing
  # is speaking is a harmless no-op, so both backends are covered unconditionally.
  # State file is two lines: process-group id, then the temp text file path.
  local pgid="" tf=""
  if [ -e "$STATE" ]; then
    pgid="$(sed -n 1p "$STATE" 2>/dev/null || true)"
    tf="$(sed -n 2p "$STATE" 2>/dev/null || true)"
  fi
  if [ -n "$pgid" ] && [ "$pgid" -gt 1 ] 2>/dev/null; then
    kill -TERM -- "-$pgid" 2>/dev/null || true
  fi
  # When piper is reached through `nix shell`, nix puts it in its OWN process
  # group, so it survives the signal above and keeps synthesising into a dead
  # pipe. Matching on the exact temp path — which appears in piper's argv via -i
  # — finishes the job. A bare prefix pattern would be too blunt: any shell whose
  # command line merely mentions it would match too. Redundant but harmless once
  # piper is installed directly and is a real member of the group.
  if [ -n "$tf" ]; then
    pkill -f -- "$tf" >/dev/null 2>&1 || true
    rm -f "$tf"
  fi
  spd-say -S >/dev/null 2>&1 || true
  rm -f "$STATE"
}

# Synthesise one text file through one voice, synchronously. Shared by the
# keybind path (--play) and the voice audition path (--demo).
_pipe() {
  local model="$1" tf="$2" speed="$3" rate lscale engine=() st
  local errf; errf="$(mktemp -t say-clip-err.XXXXXX)"

  if [ "$BACKEND" = "kokoro" ]; then
    rate=24000
    # kokoro takes speed directly: >1 is faster, same sense as SAY_SPEED.
    engine=(kokoro-say --voice "$model" --lang "$KOKORO_LANG" --speed "$speed" -i "$tf")
  else
    rate="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['audio']['sample_rate'])" \
      "$model.json" 2>/dev/null || echo 22050)"
    # piper scales duration per phoneme, so faster speech means a SHORTER scale.
    lscale="$(awk -v s="$speed" 'BEGIN{printf "%.4f", (s>0 ? 1.0/s : 1.0)}')"
    # Optional smoothness lever. Kept as an if rather than `[ -n .. ] && ..` so an
    # unset value can never become the failing last command of a list under set -e.
    local extra=()
    if [ -n "$NOISE_W" ]; then extra+=(--noise-w-scale "$NOISE_W"); fi
    engine=("${PIPER[@]}" -m "$model" -i "$tf" --output-raw --length-scale "$lscale"
            --sentence-silence 0.35 ${extra[@]+"${extra[@]}"})
  fi

  local player=(play -q -t raw -r "$rate" -e signed -b 16 -c 1 -)
  if command -v pw-play >/dev/null 2>&1; then
    player=(pw-play --raw --rate="$rate" --channels=1 --format=s16 -)
  fi

  # Both engines stream per sentence, so playback starts before the paragraph
  # has finished rendering.
  set +e
  "${engine[@]}" 2>"$errf" | "${player[@]}" >/dev/null 2>&1
  st=${PIPESTATUS[0]}
  set -e
  # 143/130/141 are our own stop (SIGTERM/SIGINT/SIGPIPE). Anything else is the
  # engine genuinely failing, and must never be silent again.
  case "$st" in
    0|143|130|141) ;;
    *) toast "Read aloud: $BACKEND failed ($(head -c 120 "$errf" | tr '\n' ' '))" ;;
  esac
  rm -f "$errf"
}

# Private subcommand: invoked through setsid so it leads its own process group,
# and records its PID (== PGID) plus the temp path as the stop handle.
_play() {
  local model="$1" tf="$2" speed="$3"
  printf '%s\n%s\n' "$$" "$tf" > "$STATE"
  _pipe "$model" "$tf" "$speed"
  rm -f "$tf"
}

# Markdown/terminal prose -> something worth listening to.
#
# Order matters: fenced code goes first (so its contents never reach the inline
# rules), then rules/emoji, then inline markup, and identifiers are de-snaked
# last so "augment_parts_sam3.py" speaks as words rather than one long mangle.
# NOTE: the program is passed via -c, not a heredoc on stdin — stdin is already
# carrying the clipboard text, and a heredoc would clobber it (silently, with an
# empty result).
read -r -d '' _SPEAKABLE_PY <<'PY' || true
import re, sys

text = sys.stdin.read()

# Fenced code: announce it, don't read it. You can see the block; the audio
# just needs to tell you it skipped something so you don't lose your place.
text = re.sub(r"```.*?```", " . code block . ", text, flags=re.S)
text = re.sub(r"~~~.*?~~~", " . code block . ", text, flags=re.S)

# Links: keep the label, drop the URL. A spoken URL is pure noise.
text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
text = re.sub(r"https?://\S+", " link ", text)

def deident(m):
    """Inline `code` -> speakable words: snake/path separators become spaces."""
    return " " + re.sub(r"[_/\-]+", " ", m.group(1)) + " "

text = re.sub(r"`([^`]*)`", deident, text)

# Arrows and dashes carry "then/becomes" and parenthetical meaning; a comma is
# what actually produces the pause, since espeak ignores the glyphs themselves.
text = re.sub(r"[→←↔⇒⇐➜▸►]", ", ", text)
text = re.sub(r"\s*[—–]\s*", ", ", text)

# Box drawing, block elements, emoji, dingbats, misc symbols: drop outright.
text = re.sub(
    r"[\u2500-\u257F\u2580-\u259F\u25A0-\u25FF\u2600-\u27BF"
    r"\u2B00-\u2BFF\uFE0F\u2190-\u21FF"
    r"\U0001F000-\U0001FAFF]",
    "",
    text,
)

# Table rows -> comma-separated; separator rows vanish entirely.
out = []
for line in text.splitlines():
    s = line.strip()
    if re.fullmatch(r"[\|\s:\-+=_*#~]*", s):   # rule / separator / empty
        out.append("")
        continue
    if s.startswith("|"):
        s = ", ".join(c.strip() for c in s.strip("|").split("|") if c.strip())
    s = re.sub(r"^\s*#{1,6}\s*", "", s)        # headings
    s = re.sub(r"^\s*>+\s*", "", s)            # blockquote
    s = re.sub(r"^\s*[-*+]\s+", "", s)         # bullets
    s = re.sub(r"^\s*\d+[.)]\s+", "", s)       # numbered items
    out.append(s)
text = "\n".join(out)

text = text.replace("**", "").replace("__", "")
text = re.sub(r"(?<!\w)[*_](?=\w)|(?<=\w)[*_](?!\w)", "", text)  # stray emphasis
text = re.sub(r"[ \t]+", " ", text)
text = re.sub(r"\s+([,.])", r"\1", text)
text = re.sub(r"(,\s*){2,}", ", ", text)
text = re.sub(r"\n{2,}", ". ", text)     # paragraph break -> sentence pause
text = re.sub(r"\s*\n\s*", " ", text)
text = re.sub(r"\s*\.\s*(\.\s*)+", ". ", text)
text = text.strip()

limit = int(sys.argv[1])
if len(text) > limit:
    text = text[:limit] + " . truncated ."

sys.stdout.write(text)
PY

_speakable() {
  python3 -c "$_SPEAKABLE_PY" "$MAXCHARS"
}

case "${1:-}" in
  --stop) stop; exit 0 ;;
  --dry)  wl-paste -n 2>/dev/null | _speakable; echo; exit 0 ;;
  --play) shift; _play "$@"; exit 0 ;;
  --demo)
    # Audition every installed voice on the SAME text, so the comparison is
    # controlled. Prefers the clipboard — judging on the material you actually
    # read beats a canned sentence — but caps it so a long paste doesn't turn
    # the audition into a recital. Ctrl-C to bail out early.
    demo_text="$(wl-paste -n 2>/dev/null | _speakable || true)"
    [ -z "$demo_text" ] && demo_text="Colour is still our splitting proxy. It fails when a semantic boundary is not a colour boundary."
    demo_text="${demo_text:0:240}"
    dtf="$(mktemp -t say-clip-tts.XXXXXX)"
    if [ "$BACKEND" = "kokoro" ]; then
      # Only the voices matching the active lang; a British voice under lang=a
      # (or the reverse) mispronounces rather than switching accent.
      for v in "${KOKORO_VOICES[@]}"; do
        case "$v" in "$KOKORO_LANG"*) ;; *) continue ;; esac
        echo "  $v"
        printf '%s. %s\n' "${v#??}" "$demo_text" > "$dtf"
        _pipe "$v" "$dtf" "$SPEED"
      done
      rm -f "$dtf"
      exit 0
    fi
    for m in "$VOICES_DIR"/*.onnx; do
      [ -e "$m" ] || { echo "  (no voices installed)"; break; }
      b="$(basename "$m" .onnx)"
      # "en_US-amy-medium" is unpronounceable; announce it as "amy, medium".
      spoken="$(echo "$b" | awk -F- '{print $2 ", " $3}' | tr '_' ' ')"
      echo "  $b"
      printf '%s. %s\n' "$spoken" "$demo_text" > "$dtf"
      _pipe "$m" "$dtf" "$SPEED"
    done
    rm -f "$dtf"
    exit 0 ;;
  --voices)
    if [ "$BACKEND" = "kokoro" ]; then
      echo "backend: kokoro    lang: $KOKORO_LANG"
      for v in "${KOKORO_VOICES[@]}"; do
        if [ "$v" = "$KOKORO_VOICE" ]; then echo "* $v (default)"; else echo "  $v"; fi
      done
      exit 0
    fi
    echo "backend: $BACKEND    voices dir: $VOICES_DIR"
    for m in "$VOICES_DIR"/*.onnx; do
      [ -e "$m" ] || { echo "  (none installed)"; break; }
      b="$(basename "$m" .onnx)"
      if [ "$b" = "$PIPER_VOICE" ]; then echo "* $b (default)"; else echo "  $b"; fi
    done
    exit 0 ;;
esac

# Toggle: the state file IS the state, same trick as the idle-inhibit bind.
if [ -e "$STATE" ]; then
  stop
  toast "Read aloud: stopped"
  exit 0
fi

text="$(wl-paste -n 2>/dev/null | _speakable || true)"
if [ -z "$text" ]; then
  toast "Read aloud: clipboard empty"
  exit 0
fi

toast "Read aloud: speaking"

if [ "$BACKEND" = "kokoro" ] || [ "$BACKEND" = "piper" ]; then
  # kokoro addresses voices by name, piper by model path.
  if [ "$BACKEND" = "kokoro" ]; then voice="$KOKORO_VOICE"; else voice="$MODEL"; fi
  tf="$(mktemp -t say-clip-tts.XXXXXX)"
  printf '%s\n' "$text" > "$tf"
  # Placeholder so an immediate second press still reads as "speaking" and stops
  # rather than starting a second voice; --play overwrites line 1 with the PGID.
  printf '0\n%s\n' "$tf" > "$STATE"
  # setsid --wait keeps this subshell alive for the whole playback, so the state
  # file is cleared when speech genuinely ends, not when the launcher returns.
  ( setsid --wait "$0" --play "$voice" "$tf" "$SPEED" >/dev/null 2>&1 || true
    rm -f "$STATE" "$tf" ) &
  disown
else
  args=(-r "$RATE")
  [ -n "$MODULE" ] && args+=(-o "$MODULE")
  [ -n "$VOICE" ]  && args+=(-t "$VOICE")
  touch "$STATE"
  # -w blocks until the message finishes, so the subshell can clear the state
  # file at the real end of speech. Backgrounded so the bind returns immediately.
  # "--" guards against clipboard text that starts with a dash.
  ( spd-say -w "${args[@]}" -- "$text" >/dev/null 2>&1 || true; rm -f "$STATE" ) &
  disown
fi
