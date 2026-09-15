#!/usr/bin/env bash
# Is the ignore file telling the truth about the index?
#
# Reports files git is TRACKING even though a .gitignore rule matches them. That
# happens whenever a rule is added AFTER the files — gitignore has no power over
# anything already in the index — and it stays invisible because nothing ever
# compares the declared boundary against the actual one.
#
# Generic: no per-repo configuration, nothing project-specific. That is why it
# lives here rather than being copied into each repo, where the copies would drift.
#
# Silent unless there is something to say, and silent outside a git repo.
#
# The fix for a legitimate hit is to DECLARE the exception with a negation rule,
# never to remove this check. Note `Images/` + `!Images/Sub/` does nothing — a file
# cannot be re-included when its parent DIRECTORY is excluded; use `Images/*`.
#
# ⚠️ `git check-ignore -v <file>` reports NO RULE for a tracked file and exits 1.
# Use `git check-ignore -v --no-index <file>` to see which rule actually caught it.
#
# Direction B — knowledge buried in a fully-ignored tree — is deliberately not
# wired: it over-fires on generated output until scoped per repo. By hand:
#   fd -e md -t f . --no-ignore --exclude .git | while read -r f; do
#     git check-ignore -q "$f" && ! git ls-files --error-unmatch "$f" >/dev/null 2>&1 && echo "$f"; done

set -uo pipefail

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[[ -n "$root" && -d "$root" ]] || exit 0
cd "$root" || exit 0

hits=$(git ls-files -i -c --exclude-standard 2>/dev/null) || exit 0
[[ -n "$hits" ]] || exit 0

# shellcheck disable=SC2016  # the python body is single-quoted on purpose
python3 -c '
import json, sys
hits = sys.argv[1].splitlines()
shown = "\n".join("  " + l for l in hits[:20])
more  = f"\n  ... and {len(hits) - 20} more" if len(hits) > 20 else ""
print(json.dumps({
  "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext":
    f"[ignore-vs-index] {len(hits)} file(s) are TRACKED despite matching a gitignore "
    f"rule in this repo:\n\n{shown}{more}\n\n"
    "Gitignore has no power over files already in the index, so this is usually a rule "
    "added after the files. Either they should be untracked, or the exception is "
    "legitimate and belongs in .gitignore as a negation rule so the file states what is "
    "actually true. Do not silence the check. `git check-ignore -v --no-index <file>` "
    "shows which rule caught it — plain check-ignore reports nothing for tracked files."},
  "systemMessage": f"[ignore-vs-index] {len(hits)} tracked file(s) match an ignore rule — see context.",
}))' "$hits"
