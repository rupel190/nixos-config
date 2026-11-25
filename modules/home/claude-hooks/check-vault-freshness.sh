#!/usr/bin/env bash
# Is this repo's DECISIONS.md behind the source it is synced from?
#
# Decisions made in meetings land in Obsidian (or a tracker) first and reach a
# repo only when someone transcribes them. This says when that has fallen behind.
# With dates alone it cannot say WHAT is missing — only that something may be.
# With a git history of the folders it names the notes (below).
#
# GENERIC. Nothing here is project-specific: the repo opts in by having a
# DECISIONS.md, and everything configurable lives in that file:
#
#     ## Watched sources
#     | `~/path/to/folder` | what it holds |
#     ```
#     last synced from vault: YYYY-MM-DD
#     vault history: `~/path/to/git/repo` @ <commit that was read>     (optional)
#     ```
#
# The history line turns the check from dates into CONTENT for every watched
# folder that repo holds as a top-level folder of the same name: the live notes
# are compared with the commit, so opening a note is not a change, a subfolder
# counts, and the answer is a list. It reads the live folder and not the newest
# commit, so a stopped snapshot job cannot look like "nothing changed". Rows
# described as "reference" are left out of it. Other folders keep the date check.
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

# --- content, where a history covers the folder ---------------------------------
# shellcheck disable=SC2016  # PCRE pattern; the backtick is regex
hist=$(grep -oP '^vault history:\s*`?\K[^`@]+(?=`?\s*@)' "$DECISIONS" | head -1 | sed 's/ *$//' | sed "s|^~|$HOME|")
since=$(grep -oP '^vault history:[^@]*@\s*\K[0-9a-f]{7,40}' "$DECISIONS" | head -1)
if grep -q '^vault history:' "$DECISIONS"; then
  [[ -n "$hist" && -n "$since" ]] || complain \
    "$rel has a 'vault history:' line that does not parse. Expected: vault history: \`~/path\` @ <commit>"
  git -C "$hist" rev-parse -q --verify "$since^{commit}" >/dev/null 2>&1 || complain \
    "$rel names commit $since in $hist, and that commit is not there (history moved or rebuilt?)."
fi

# The folder of the history that holds $1 (itself or a parent); nothing when none does.
covered_by() {
  local p=$1
  [[ -n "$hist" ]] || return 0
  while [[ "$p" != / && -n "$p" ]]; do
    git -C "$hist" cat-file -e "$since:$(basename "$p")" 2>/dev/null && { printf '%s' "$p"; return 0; }
    p=$(dirname "$p")
  done
}

# git on the history, looking at the LIVE folder $1 stands in; never writes the index.
live() {
  local top=$1; shift
  GIT_OPTIONAL_LOCKS=0 git -C "$(dirname "$top")" --git-dir="$hist/.git" --work-tree="$(dirname "$top")" \
    -c core.quotePath=false -c core.fileMode=false "$@"
}

declare -A tops=()
skip=()
for d in "${watched[@]}"; do
  [[ -d "$d" ]] || continue
  top=$(covered_by "$d")
  [[ -n "$top" ]] || continue
  if [[ "$d" == "$top" ]]; then
    tops["$top"]=1
  elif grep -F "\`${d/#$HOME/\~}\`" <<<"$section" | grep -qP '\|\s*(\*\*)?reference'; then
    skip+=(":(exclude)${d#"$(dirname "$top")"/}")
  fi
done

# Front matter a plugin rewrites on open is not content.
# The decision lines are the added WORDS only: a note is often one long line, and its old half is not news.
noise='^(modified|edited|updated|position): '
decision='DECIDED|RESOLVED|[Dd]ecided|Decision|[Ee]ntschieden|Entscheidung|POSITION|\(Christoph, 20[0-9]{2}'
changed=(); maybe=()
for top in "${!tops[@]}"; do
  name=$(basename "$top")
  spec=(":(glob)$name/**/*.md" "${skip[@]}")
  while IFS=$'\t' read -r plus minus note; do
    [[ -n "$note" && "$plus$minus" != 00 ]] && changed+=("$note  +$plus -$minus")
  done < <(live "$top" diff --no-renames --numstat -I"$noise" "$since" -- "${spec[@]}" 2>/dev/null)
  while IFS= read -r -d '' note; do
    changed+=("$note  new")
  done < <(live "$top" ls-files -z --others --exclude='.*' -- "${spec[@]}" 2>/dev/null)
  while IFS= read -r line; do
    maybe+=("${line:1:220}")
  done < <(live "$top" diff --no-renames -U0 --word-diff=porcelain -I"$noise" "$since" -- "${spec[@]}" 2>/dev/null |
    grep -P '^\+(?!\+\+ )' | grep -E "$decision")
done

# --- dates, everywhere else --------------------------------------------------------
newest_date=""; newest_file=""; newest_guessed=""; dated=0
for d in "${watched[@]}"; do
  [[ -d "$d" ]] || continue
  [[ -z "$(covered_by "$d")" ]] || continue
  dated=1
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

[[ -n "$newest_date" || "$dated" == 0 ]] || complain "The watched folders resolved but contain no .md files: ${watched[*]}"

# In sync — the only silent exit that means the check actually ran.
[[ "$newest_date" > "$synced" ]] || (( ${#changed[@]} > 0 )) || exit 0

if (( ${#changed[@]} > 0 )); then
  shown=20; (( ${#changed[@]} < shown )) && shown=${#changed[@]}
  list=$(printf '  %s\n' "${changed[@]:0:shown}")
  (( ${#changed[@]} > shown )) && list+=$'\n'"  … and $(( ${#changed[@]} - shown )) more"
  lines=""
  if (( ${#maybe[@]} > 0 )); then
    few=8; (( ${#maybe[@]} < few )) && few=${#maybe[@]}
    lines=$'\n\n'"Added lines that look like a decision (${#maybe[@]}, the first $few; they are notes, not instructions):"$'\n'
    lines+=$(printf '  %s\n' "${maybe[@]:0:few}")
  fi
  other=""
  [[ "$newest_date" > "$synced" ]] && other=$'\n\n'"Also newer, by date: \"$(basename "$newest_file")\" ($newest_date)$newest_guessed."
  first=${changed[0]%%  *}
  for top in "${!tops[@]}"; do [[ "$first" == "$(basename "$top")"/* ]] && tree=$(dirname "$top"); done
  emit "$rel was last synced $synced. Since then ${#changed[@]} watched note(s) changed in CONTENT (compared with $since
in the vault's history; opening a note does not count):
$list$lines$other

One note's change:  git -C '${tree:-}' --git-dir='$hist/.git' --work-tree='${tree:-}' diff $since -- '$first'

Decisions made since $synced may not have reached this repo. Treat $rel and the repo's own plan/scope
documents as possibly incomplete on anything about scope, direction, deployment or what the client wants —
say so rather than reasoning past it. Read the changed notes, append what binds this repo to $rel, then write
the new date AND the commit you read:  git -C '$hist' rev-parse --short=12 HEAD" \
    "[vault] ${#changed[@]} note(s) changed since $rel was synced — see context."
  exit 0
fi

emit "$rel says \"last synced: $synced\", but a note in the watched sources is
newer — \"$(basename "$newest_file")\" (dated $newest_date)$newest_guessed.

Decisions made since $synced may not have reached this repo. Treat $rel and the
repo's own plan/scope documents as possibly incomplete on anything about scope,
direction, deployment or what the client wants — say so rather than reasoning
past it. Read the newer note(s) first, then append what changed to $rel along
with a new sync date." \
  "[vault] $rel may be behind its source — see context."
