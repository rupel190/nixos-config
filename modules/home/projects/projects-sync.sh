#!/usr/bin/env bash
# Clone the repos this config expects under ~/projects; skip whatever is there.
#
# Deliberately NOT a home.activation step. A rebuild must not depend on the
# network or on a reachable ssh-agent, and `nh os switch` has no business
# fetching repositories. Nix owns the LIST; you run the CLONING.
#
# Never touches a working tree it did not create: an existing path is only
# inspected, never reset, pulled or deleted.
set -uo pipefail

root="$HOME/projects"
mkdir -p "$root"

cloned=0 present=0 mismatched=0

while IFS=$'\t' read -r rel url; do
  [ -n "${rel:-}" ] || continue
  dest="$root/$rel"

  if [ -e "$dest" ]; then
    have=$(git -C "$dest" remote get-url origin 2>/dev/null || echo "")
    if [ -z "$have" ]; then
      printf '  %-34s exists but is not a git checkout\n' "$rel"
      mismatched=$((mismatched + 1))
    elif [ "$have" != "$url" ]; then
      # ssh vs https for the same repo is the usual cause, and it is how one
      # checkout drifts into two. Report, never rewrite.
      printf '  %-34s origin is %s\n' "$rel" "$have"
      printf '  %-34s expected %s\n' "" "$url"
      mismatched=$((mismatched + 1))
    else
      present=$((present + 1))
    fi
    continue
  fi

  printf '  %-34s cloning...\n' "$rel"
  mkdir -p "$(dirname "$dest")"
  if git clone --quiet "$url" "$dest"; then
    cloned=$((cloned + 1))
  else
    printf '  %-34s CLONE FAILED (ssh key loaded?)\n' "$rel"
    mismatched=$((mismatched + 1))
  fi
done < "$MANIFEST"

printf '\n%d cloned, %d already present, %d need attention\n' "$cloned" "$present" "$mismatched"
[ "$mismatched" -eq 0 ]
