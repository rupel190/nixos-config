{ pkgs, config, ... }:
let
  home = config.home.homeDirectory;
  videos = "/mnt/silo/videos"; # ~/Videos links here
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
        # Steam's web and library caches: hundreds of files churn weekly, each a slow remote delete in the mirror
        "/.local/share/Steam/config/htmlcache/" "/.local/share/Steam/appcache/"
        # unlocked Cryptomator vaults: the encrypted vault (~/OneDrive/Vault) is backed up, never its plaintext view
        "/.local/share/Cryptomator/mnt/"
        "/games/beamng-mod-backups" "/games/gtav-layers" "/.local/share/gnome-boxes"
        # app caches (Electron/Chromium/Firefox, Flatpak)
        "/.config/**/Cache/" "/.config/**/Code Cache/" "/.config/**/GPUCache/" "/.config/**/DawnCache/"
        "/.config/**/DawnGraphiteCache/" "/.config/**/DawnWebGPUCache/" "/.config/**/GrShaderCache/"
        "/.config/**/ShaderCache/" "/.config/**/Service Worker/CacheStorage/"
        "/.config/**/Service Worker/ScriptCache/" "/.config/**/Crashpad/" "/.config/**/cache2/"
        "/.var/app/*/cache/" "/.var/app/*/config/**/Cache/" "/.var/app/*/config/**/Code Cache/"
        "/.var/app/*/config/**/GPUCache/" "/.var/app/*/config/**/Dawn*Cache/"
        "/.var/app/*/config/**/CacheStorage/" "/.var/app/*/config/**/ScriptCache/"
        "/.var/app/*/config/CurseForge/agent/FileCache/"
        "/.config/zen/*/storage/default/*/cache/" "/.config/chromium-headless/" "/.config/.wrangler/logs/"
        "/.local/share/vicinae/clipboard-data/" "/.local/share/digikam/thumbnails-digikam.db"
        "/.claude/jobs/*/tmp/"
        # re-downloadable dependencies
        "node_modules/" ".venv/" "__pycache__/" "/projects/**/.claude/worktrees/"
        ".yarn/cache/" ".yarn/unplugged/" "/go/pkg/" "/.m2/repository/"
        "/.arduino15/packages/" "/.arduino15/staging/"
        "/projects/nixpkgs-wezterm-fix/" # its one unpushed commit is nixpkgs-wezterm-fix.patch next to it
        # build caches, rebuilt by the project
        ".godot/" ".next/"
        # programs: Steam's runtimes and Proton builds, Bitwig's sound packages, the Hytale and MXA clients (its Mods and game files stay in)
        "/.local/share/Steam/steamrt64/" "/.local/share/Steam/compatibilitytools.d/"
        "/.local/share/Steam/ubuntu12_32/" "/.local/share/Steam/ubuntu12_64/" "/.local/share/Steam/linux32/"
        "/.local/share/Steam/linux64/" "/.local/share/Steam/steamui/" "/.local/share/Steam/clientui/"
        "/.BitwigStudio/installed-packages/" "/.var/app/com.hypixel.HytaleLauncher/data/Hytale/install/"
        "/.local/share/Steam/steamapps/compatdata/*/pfx/drive_c/users/steamuser/AppData/Roaming/mxa-launcher/clients/*/versions/"
        "/.local/share/nvim/lazy/" "/.local/share/nvim/mason/" "/.local/share/pnpm/"
        "/.bun/install/cache/" "/.cargo/registry/" "/.cargo/git/"
        "/.local/share/containers/" "/.local/share/flatpak/" "/.local/share/uv/"
        "/.local/state/affinity-v3/work/"
        # regenerable pipeline output (sittings/ and findings-data/ stay)
        "/projects/recustomize/stitching-pipeline/tests/output/test_batch_segment/"
        "/projects/recustomize/stitching-pipeline/tests/output/variants/"
        "/projects/recustomize/stitching-pipeline/tests/output/renderer-history/"
        "/projects/recustomize/stitching-pipeline/tests/output/test_segmentation/"
        # Wine and Proton prefixes: keep each game's users/ dir (saves), drop the Windows install
        "drive_c/windows/"
        "/.local/share/Steam/steamapps/compatdata/*/pfx/drive_c/Program Files/"
        "/.local/share/Steam/steamapps/compatdata/*/pfx/drive_c/Program Files (x86)/"
        "/.local/share/Steam/steamapps/compatdata/*/pfx/drive_c/users/steamuser/AppData/Local/Temp/"
        "/.local/share/Steam/steamapps/compatdata/*/pfx/dosdevices/"
      ];
    }
    {
      name = "home-media";
      sources = [ videos "${home}/Pictures" "${home}/Music" ];
      excludes = [ ];
    }
    {
      # silo folders that exist nowhere else (console saves, others' phone and photo backups)
      name = "silo";
      sources = [ "/mnt/silo/games" "/mnt/silo/for-others" ];
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
      # At boot the notification daemon may not be up yet; a failed notify must not end the run unlogged
      notify() { echo "''${*: -2}"; notify-send "$@" || true; }
      # A boot-time catch-up starts before /mnt/backup is mounted: wait up to 10 min
      for _ in $(seq 20); do
        mountpoint -q /mnt/backup && break
        sleep 30
      done
      if ! mountpoint -q /mnt/backup; then
        notify -u critical "Backup failed" "/mnt/backup is not mounted"
        exit 1
      fi

      failed=0
      snapshot() {
        local name="$1"; shift
        local opts=()
        while [ "$1" != "--" ]; do opts+=("$1"); shift; done
        shift
        # a missing source (e.g. silo not mounted) would otherwise pass as exit 23 and rotate it away
        for s in "$@"; do
          if [ ! -e "$s" ]; then
            notify -u critical "Backup failed" "$name: $s missing"
            failed=1
            return
          fi
        done

        local dest="${root}/$name" date
        date=$(date +%Y-%m-%d)
        mkdir -p "$dest"
        [ -d "$dest/latest" ] && opts+=("--link-dest=$dest/latest")

        echo "=== $name -> $dest/$date ==="
        local rc=0
        rsync -aHAX --delete --delete-excluded "''${opts[@]}" "$@" "$dest/$date/" || rc=$?
        # 23 = some files unreadable, 24 = files vanished mid-run; the snapshot is still usable
        if [ "$rc" -ne 0 ] && [ "$rc" -ne 23 ] && [ "$rc" -ne 24 ]; then
          notify -u critical "Backup failed" "$name: rsync exit $rc"
          failed=1
          return
        fi
        ln -snf "$date" "$dest/latest"

        find "$dest" -mindepth 1 -maxdepth 1 -type d -name '????-??-??' | sort | head -n -${toString keep} | xargs -r rm -rf --
        local note=""
        [ "$rc" -ne 0 ] && note=" (rsync exit $rc, see journal)"
        notify "Backup complete" "$name → $date$note"
      }

      ${pkgs.lib.concatMapStrings runJob jobs}
      exit "$failed"
    '';
  };
in
{
  home.packages = [ backupScript ];

  # Videos live on the 12TB HDD; the home-media job backs up the target, not the link
  home.file."Videos".source = config.lib.file.mkOutOfStoreSymlink videos;

  systemd.user.services.rsync-backups = {
    Unit.Description = "Weekly rsync snapshots of home to /mnt/backup";
    Unit.X-RestartIfChanged = false; # long run; see proton-mirror.nix
    Service = {
      Type = "oneshot";
      ExecStart = "${backupScript}/bin/rsync-backups";
      Nice = 19;
      IOSchedulingClass = "idle";
      # Keeps the snapshot's page cache from crowding the desktop during a 400 GB run
      MemoryHigh = "4G";
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
