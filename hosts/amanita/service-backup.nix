{ pkgs, config, username, ... }:
let
  out = "/mnt/backup/current/services"; # newest archives, mirrored to Proton with the rest of current/
  history = "/mnt/backup/services-history";
  keep = 4; # weekly sets kept in history
  limit = 5; # GB; a bigger source is skipped and fails the run instead of filling the drive

  # settings and databases only: no artwork, thumbnails, logs or media
  sources = {
    jellyfin = { path = "/var/lib/jellyfin"; excludes = [ "metadata" "transcodes" "cache" "log" "trickplay" "subtitles" "attachments" ]; };
    radarr = { path = "/var/lib/radarr"; excludes = [ "MediaCover" "logs" ]; };
    sonarr = { path = "/var/lib/sonarr"; excludes = [ "MediaCover" "logs" ]; };
    prowlarr = { path = "/var/lib/private/prowlarr"; excludes = [ "logs" ]; };
    bazarr = { path = "/var/lib/bazarr"; excludes = [ "cache" "log" ]; };
    sabnzbd = { path = "/var/lib/sabnzbd"; excludes = [ "logs" ]; };
    beszel = { path = "/var/lib/private/beszel-hub"; excludes = [ ]; };
    # no longer running, kept for their old data
    gatus-old = { path = "/var/lib/private/gatus"; excludes = [ ]; };
    photoprism-old = { path = "/var/lib/private/photoprism"; excludes = [ "cache" "originals" "import" "sidecar" ]; };
    mysql-old = { path = "/var/lib/mysql"; excludes = [ ]; };
  };

  save = name: s: ''
    save ${name} ${s.path} ${pkgs.lib.escapeShellArgs s.excludes}
  '';

  script = pkgs.writeShellApplication {
    name = "service-backup";
    runtimeInputs = with pkgs; [ coreutils findutils gnutar rsync sqlite util-linux zstd config.services.postgresql.finalPackage ];
    text = ''
      mountpoint -q /mnt/backup || { echo "/mnt/backup is not mounted"; exit 1; }
      umask 077
      set_dir="${history}/$(date +%F)"
      mkdir -p "$set_dir" ${out}
      tmp=$(mktemp -d -p /var/tmp service-backup.XXXX)
      trap 'rm -rf "$tmp"' EXIT
      failed=0

      save() {
        local name="$1" src="$2"; shift 2
        local opts=() e size
        for e in "$@"; do opts+=("--exclude=$e"); done
        if [ ! -d "$src" ]; then echo "$name: $src missing, skipped"; return; fi
        size=$(du -sb "''${opts[@]}" "$src" | cut -f1)
        if [ "$size" -gt $((${toString limit} * 1000000000)) ]; then
          echo "$name: $((size / 1000000)) MB is over the limit, skipped"
          failed=1
          return
        fi
        # files as they are, sqlite databases through their own backup so a running service cannot tear them
        rsync -a "''${opts[@]}" --exclude='*.db-wal' --exclude='*.db-shm' "$src/" "$tmp/$name/"
        find "$tmp/$name" -type f -name '*.db' -printf '%P\0' | while IFS= read -r -d "" db; do
          if sqlite3 "$src/$db" "PRAGMA schema_version" >/dev/null 2>&1; then
            rm -f "$tmp/$name/$db"
            sqlite3 "$src/$db" ".timeout 30000" ".backup '$tmp/$name/$db'" || echo "$name: backup of $db failed" >> "$tmp/errors"
          fi
        done
        tar -C "$tmp" -cf - "$name" | zstd -q -10 -T4 -o "$set_dir/$name.tar.zst" -f
        rm -rf "''${tmp:?}/$name"
        echo "$name: $(du -h "$set_dir/$name.tar.zst" | cut -f1)"
      }

      ${pkgs.lib.concatStrings (pkgs.lib.mapAttrsToList save sources)}
      # RomM and everything else in postgres
      if runuser -u postgres -- pg_dumpall | zstd -q -10 -T4 -o "$set_dir/postgresql.sql.zst" -f; then
        echo "postgresql: $(du -h "$set_dir/postgresql.sql.zst" | cut -f1)"
      else
        echo "postgresql: dump failed"; failed=1
      fi
      if [ -s "$tmp/errors" ]; then cat "$tmp/errors"; failed=1; fi

      # readable for the mirror, which runs as the user
      chown -R ${username}:users ${history} ${out}
      for f in "$set_dir"/*; do ln -f "$f" "${out}/$(basename "$f")"; done
      find ${history} -mindepth 1 -maxdepth 1 -type d -name '????-??-??' | sort | head -n -${toString keep} | xargs -r rm -rf --
      exit "$failed"
    '';
  };
in
{
  systemd.services.service-backup = {
    description = "Weekly archives of the services' settings and databases";
    unitConfig.RequiresMountsFor = "/mnt/backup";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${script}/bin/service-backup";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };
  systemd.timers.service-backup = {
    description = "Weekly service backup timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun *-*-* 03:30:00"; # before rsync-backups (04:00) and the Proton mirror (08:00)
      Persistent = true;
    };
  };
}
