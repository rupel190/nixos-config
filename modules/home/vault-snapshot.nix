{ pkgs, config, ... }:
let
  home = config.home.homeDirectory;
  vault = "${home}/Documents/SkeletonCrypt/01-Projects/Recustomize";
  dest = "${home}/.local/share/recustomize-vault-history";
  folders = [ "Shared" "Team" ];

  # Relay live-syncs these folders between several people and keeps no history; it has emptied notes while
  # showing "Synced" (No-Instructions/Relay#137). Read-only towards the vault: nothing here writes or pulls into it.
  snapshotScript = pkgs.writeShellApplication {
    name = "vault-snapshot";
    runtimeInputs = with pkgs; [ git rsync libnotify coreutils findutils util-linux ];
    text = ''
      umask 077 # the founders' notes are in here
      notify() { echo "''${*: -2}"; notify-send -a vault-snapshot "$@" || true; }
      mkdir -p ${dest}
      exec 9> ${dest}/.lock
      flock -n 9 || exit 0
      cd ${dest}
      if [ ! -d .git ]; then
        git init -q -b main
        echo /.lock > .git/info/exclude
        git config user.name vault-snapshot
        git config user.email vault-snapshot@localhost
        git config commit.gpgsign false
      fi

      warn=()
      for f in ${pkgs.lib.escapeShellArgs folders}; do
        src="${vault}/$f"
        # an empty or missing folder is a fault, not a state to copy over the last good one
        if [ ! -d "$src" ] || [ -z "$(find "$src" -type f -name '*.md' -print -quit)" ]; then
          if [ -d "$f" ]; then
            notify -u critical "Vault: $f is missing or empty" "Not copied. Last good state: ${dest}/$f"
          fi
          continue
        fi

        while IFS= read -r -d "" n; do
          new=$(stat -c %s "$src/$n" 2>/dev/null || echo gone)
          [ "$new" = gone ] && continue
          old=-1
          [ -f "$f/$n" ] && old=$(stat -c %s "$f/$n")
          if [ "$new" -eq 0 ] && [ "$old" -ne 0 ]; then
            warn+=("EMPTY: $f/$n")
          elif [ "$old" -ge 400 ] && [ $(( new * 2 )) -lt "$old" ]; then
            warn+=("$old -> $new bytes: $f/$n")
          fi
        done < <(cd "$src" && find . -type f -name '*.md' -not -path '*/.*' -printf '%P\0')

        mkdir -p "$f"
        rsync -a --delete --exclude '.*' "$src/" "$f/"
      done

      git add -A
      if ! git diff --cached --quiet; then
        # a moved note shows up as a rename here, a vanished one as a deletion
        gone=$(git diff --cached -M --name-only --diff-filter=D -z -- '*.md' | tr -cd '\0' | wc -c)
        [ "$gone" -ge 5 ] && warn+=("$gone notes disappeared")
        git commit -q -m "$(date '+%Y-%m-%d %H:%M')" -m "$(printf '%s\n' "''${warn[@]}")"
      fi

      if [ "''${#warn[@]}" -gt 0 ]; then
        notify -u critical "Vault: a note lost its text" "$(printf '%s\n' "''${warn[@]}")
      Get it back: cd ${dest}; git show HEAD~1:'<note>'"
      fi
    '';
  };
in
{
  home.packages = [ snapshotScript ];

  systemd.user.services.vault-snapshot = {
    Unit.Description = "Git snapshot of the Relay-shared Recustomize folders";
    Service = {
      Type = "oneshot";
      ExecStart = "${snapshotScript}/bin/vault-snapshot";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.user.timers.vault-snapshot = {
    Unit.Description = "Snapshot the Relay-shared folders every 15 minutes";
    Timer = {
      OnBootSec = "3min";
      OnCalendar = "*:0/15";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
