#!/usr/bin/env bash
# What is drifting under ~/projects: every checkout, declared or not.
#
# Discovery-driven ON PURPOSE, unlike projects-sync. The failures worth catching
# are the ones nobody declared: a second clone of a repo you already have, a
# checkout with no remote, work sitting in a repo that has never been committed
# to. A manifest-driven audit is blind to exactly those.
#
# ⚠️ Do NOT use `rev-parse --abbrev-ref HEAD` for the branch. In a repo with no
# commits it exits 128 AND still prints "HEAD" on stdout, so a `|| fallback`
# appends a second line and every downstream comparison silently fails.
# symbolic-ref distinguishes the three states cleanly.
set -uo pipefail

root="${1:-$HOME/projects}"
attention=0

printf '%-36s %-18s %-6s %-6s %s\n' "PATH" "BRANCH" "AHEAD" "DIRTY" "ORIGIN"
printf '%.0s─' {1..108}; printf '\n'

while IFS= read -r gitdir; do
  repo=$(dirname "$gitdir")
  rel=${repo#"$root"/}
  [ "$rel" = "$repo" ] && rel=$(basename "$repo")

  flags=""
  if branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null); then
    if ! git -C "$repo" rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
      flags+=" ⛔no-commits"
      attention=$((attention + 1))
    fi
  else
    branch="DETACHED"
    flags+=" ⛔detached"
    attention=$((attention + 1))
  fi

  origin=$(git -C "$repo" remote get-url origin 2>/dev/null || echo "")
  if [ -z "$origin" ]; then
    short="⛔ none"
    flags+=" ⛔no-remote"
    attention=$((attention + 1))
  else
    case "$origin" in
      *@*:*) short=${origin#*:} ;;
      http*) short=${origin#*://}; short=${short#*/} ;;
      *) short=$origin ;;
    esac
  fi

  dirty=$(git -C "$repo" status --porcelain 2>/dev/null | wc -l)
  ahead=$(git -C "$repo" rev-list --count '@{u}..HEAD' 2>/dev/null || echo "-")
  [ "$ahead" != "-" ] && [ "$ahead" != "0" ] && flags+=" ⚠unpushed"

  printf '%-36s %-18s %-6s %-6s %s%s\n' "$rel" "${branch:0:18}" "$ahead" "$dirty" "$short" "$flags"
done < <(fd -H -I -t d '^\.git$' "$root" --max-depth 4 | sort)

printf '\n'
if [ "$attention" -gt 0 ]; then
  printf '%d condition(s) need attention.\n' "$attention"
else
  printf 'Nothing stranded: every checkout is on a branch, with commits and a remote.\n'
fi
