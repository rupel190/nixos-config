#!/usr/bin/env bash
# Is this repo's DECISIONS.md behind the source it is synced from?
#
# Decisions made in meetings land in Obsidian (or a tracker) first and reach a
# repo only when someone transcribes them. This says when that has fallen behind.
# It cannot say WHAT is missing — only that something may be.
#
# GENERIC. Nothing here is project-specific: the repo opts in by having a
# DECISIONS.md, and everything configurable lives in that file:
#
#     ## Watched sources
#     | `~/path/to/folder` | what it holds |
#     ```
#     last synced from vault: YYYY-MM-DD
#     ```
#
# A repo with no DECISIONS.md is simply not opted in — silent, no complaint.
#
# ⛔ SILENCE MUST NOT LOOK LIKE A PASS. Once a repo HAS opted in, every way this
# can fail to check speaks up. The only silent exit past that point is the one
# meaning it ran and found nothing.
#
# ⛔ Keyed on the DATE A NOTE DECLARES, never its mtime. mtime tracks touches:
# sync clients, plugins rewriting frontmatter on open, backups walking the tree.
# Observed: a note whose mtime was EARLIER than the meeting it recorded, and
# another five days past its last real edit. mtime makes this invent work.

set -uo pipefail

# shellcheck disable=SC2016  # the python body is single-quoted on purpose
emit() { python3 -c '
import json, sys
print(json.dumps({
    "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": sys.argv[1]},
    "systemMessage": sys.argv[2],
}))' "$1" "$2"; }

complain() {
  emit "[vault freshness check BROKEN] $1

Nothing is currently verifying whether decisions made outside this repo have
reached it. Treat DECISIONS.md as possibly stale until this is repaired." \
    "[vault] freshness check is broken — see context."
  exit 0
}

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[[ -n "$root" && -d "$root" ]] || exit 0

# Opt-in by convention. Not found anywhere = this repo does not use the pattern.
DECISIONS=""
for c in DECISIONS.md project/DECISIONS.md docs/DECISIONS.md doc/DECISIONS.md .github/DECISIONS.md; do
  [[ -f "$root/$c" ]] && { DECISIONS="$root/$c"; rel="$c"; break; }
done
[[ -n "$DECISIONS" ]] || exit 0

synced=$(grep -oP '^last synced from [^:]+:\s*\K[0-9]{4}-[0-9]{2}-[0-9]{2}' "$DECISIONS" | head -1)
[[ -n "$synced" ]] || complain "$rel has no parseable 'last synced from <source>: YYYY-MM-DD' line."

section=$(sed -n '/^## Watched sources/,/^---/p' "$DECISIONS")
[[ -n "$section" ]] || complain "$rel has no '## Watched sources' section, so there is nothing to check against."

# shellcheck disable=SC2016  # PCRE pattern; the backticks are regex, not command substitution
mapfile -t watched < <(printf '%s\n' "$section" | grep -oP '^\|\s*`\K[^`]+' | sed "s|^~|$HOME|")
(( ${#watched[@]} > 0 )) || complain \
  "The 'Watched sources' section in $rel has no parseable folder rows. Each needs a backticked path: | \`~/path\` | description |"

missing=()
for d in "${watched[@]}"; do [[ -d "$d" ]] || missing+=("$d"); done
(( ${#missing[@]} < ${#watched[@]} )) || complain \
  "None of the watched folders exist here: ${missing[*]} — stale paths, or the vault is not mounted."

newest_date=""; newest_file=""; newest_guessed=""
for d in "${watched[@]}"; do
  [[ -d "$d" ]] || continue
  while IFS= read -r -d '' f; do
    base=$(basename "$f")
    n=$(grep -oP '^\d{4}-\d{2}-\d{2}' <<<"$base" || true)
    [[ -n "$n" ]] || n=$(grep -oPm1 '^date:\s*\K[0-9]{4}-[0-9]{2}-[0-9]{2}' "$f" 2>/dev/null || true)
    # A note may declare its date in the BODY rather than the filename or frontmatter --
    # "**Last updated:** 2026-08-17" is the shape Obsidian working documents use here.
    # Added 2026-09-08 after this hook raised a false alarm: it fell through to mtime on a
    # note declaring 2026-08-17 in exactly this form, and cost a session's worth of reading.
    # Deliberately NOT anchored to line start: the real notes carry it mid-line, after other
    # bold runs -- "... require counsel. **Last updated:** 2026-08-17". An anchored pattern
    # matched nothing and fell straight through to mtime, which is how the false alarm happened.
    [[ -n "$n" ]] || n=$(grep -oPm1 'Last updated:?\**:?\s*\**\s*\K[0-9]{4}-[0-9]{2}-[0-9]{2}' "$f" 2>/dev/null || true)
    guessed=""
    # mtime is the LAST resort and it is labelled as one. This file's own header forbids keying
    # on mtime -- it tracks touches, not edits -- yet the fallback did exactly that, silently,
    # and an unlabelled guess is indistinguishable from a date the note actually declares.
    # Keep the fallback (a note with no date at all must still be noticed) but never let it
    # masquerade as a declaration.
    [[ -n "$n" ]] || { n=$(date -d "@$(stat -c %Y "$f")" +%F); guessed=" (no date declared -- this is the file's mtime, which tracks touches, not edits)"; }
    [[ "$n" > "$newest_date" ]] && { newest_date=$n; newest_file=$f; newest_guessed=$guessed; }
  done < <(find "$d" -maxdepth 1 -name '*.md' -type f -print0 2>/dev/null)
done

[[ -n "$newest_date" ]] || complain "The watched folders resolved but contain no .md files: ${watched[*]}"

# In sync — the only silent exit that means the check actually ran.
[[ "$newest_date" > "$synced" ]] || exit 0

emit "$rel says \"last synced: $synced\", but a note in the watched sources is
newer — \"$(basename "$newest_file")\" (dated $newest_date)$newest_guessed.

Decisions made since $synced may not have reached this repo. Treat $rel and the
repo's own plan/scope documents as possibly incomplete on anything about scope,
direction, deployment or what the client wants — say so rather than reasoning
past it. Read the newer note(s) first, then append what changed to $rel along
with a new sync date." \
  "[vault] $rel may be behind its source — see context."
