{ pkgs, config, ... }:
let
  home = config.home.homeDirectory;
  root = "/mnt/backup/current/rsync-weekly-bak";
  keep = 8; # weekly snapshots kept per job

  # name = job dir under root; sources are copied into the snapshot by basename
  jobs = [
    {
      name = "home-core";
      sources = [ "${home}/" ];
      excludes = [
        "/.cache" "/.npm" "/.yarn" "/Downloads" "/dday-recovery" "/playground"
        "/Videos" "/Pictures" "/Music" "/.local/share/Trash"
        "/.local/share/Steam/steamapps/common" "/.local/share/Steam/steamapps/shadercache"
        "/.local/share/Steam/steamapps/workshop" "/.local/share/Steam/steamapps/downloading"
        "/.local/share/Steam/steamapps/temp"
      ];
    }
    {
      name = "home-media";
      sources = [ "${home}/Videos" "${home}/Pictures" "${home}/Music" ];
      excludes = [ ];
    }
  ];

  runJob = job: ''
    snapshot ${job.name} \
      ${pkgs.lib.concatMapStringsSep " " (e: "--exclude=${pkgs.lib.escapeShellArg e}") job.excludes} \
      -- ${pkgs.lib.escapeShellArgs job.sources}
  '';

  backupScript = pkgs.writeShellApplication {
    name = "rsync-backups";
    runtimeInputs = with pkgs; [ rsync libnotify coreutils findutils util-linux ];
    text = ''
      if ! mountpoint -q /mnt/backup; then
        notify-send -u critical "Backup failed" "/mnt/backup is not mounted"
        exit 1
      fi

      failed=0
      snapshot() {
        local name="$1"; shift
        local opts=()
        while [ "$1" != "--" ]; do opts+=("$1"); shift; done
        shift

        local dest="${root}/$name" date
        date=$(date +%Y-%m-%d)
        mkdir -p "$dest"
        [ -d "$dest/latest" ] && opts+=("--link-dest=$dest/latest")

        echo "=== $name -> $dest/$date ==="
        local rc=0
        rsync -aHAX --delete "''${opts[@]}" "$@" "$dest/$date/" || rc=$?
        # 23 = some files unreadable, 24 = files vanished mid-run; the snapshot is still usable
        if [ "$rc" -ne 0 ] && [ "$rc" -ne 23 ] && [ "$rc" -ne 24 ]; then
          notify-send -u critical "Backup failed" "$name: rsync exit $rc"
          failed=1
          return
        fi
        ln -snf "$date" "$dest/latest"

        find "$dest" -mindepth 1 -maxdepth 1 -type d -name '????-??-??' | sort | head -n -${toString keep} | xargs -r rm -rf --
        local note=""
        [ "$rc" -ne 0 ] && note=" (rsync exit $rc, see journal)"
        notify-send "Backup complete" "$name → $date$note"
      }

      ${pkgs.lib.concatMapStrings runJob jobs}
      exit "$failed"
    '';
  };
in
{
  home.packages = [ backupScript ];

  systemd.user.services.rsync-backups = {
    Unit.Description = "Weekly rsync snapshots of home to /mnt/backup";
    Service = {
      Type = "oneshot";
      ExecStart = "${backupScript}/bin/rsync-backups";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.user.timers.rsync-backups = {
    Unit.Description = "Weekly rsync snapshot timer";
    Timer = {
      OnCalendar = "Sun *-*-* 04:00:00";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
