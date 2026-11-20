{ pkgs, ... }:
let
  proton-drive = pkgs.callPackage ./proton-drive/package.nix { };

  pullScript = pkgs.writeShellApplication {
    name = "pull-pi-backup";
    runtimeInputs = with pkgs; [ rsync openssh libnotify coreutils util-linux ];
    # Backups stay local: the tree includes InvoiceNinja's .env and DB dumps, never copy them to OneDrive.
    text = ''
      BACKUP_DIR="/mnt/backup/current/invoiceninja_rpi"
      PI_HOST="raspi"
      PI_BACKUP_DIR="/mnt/usbhdd/backups"

      # -t 0: stays on screen until dismissed; a plain critical one timed out unseen for weeks
      alert() { notify-send -u critical -t 0 "$1" "$2" || true; }

      echo "=== Pi Backup Pull: $(date) ==="
      if ! mountpoint -q /mnt/backup; then
        alert "Pi Backup Failed" "/mnt/backup is not mounted"
        exit 1
      fi

      # Name the unmounted-drive case in the alert instead of a bare rsync error
      # shellcheck disable=SC2029 # PI_BACKUP_DIR is meant to expand locally
      if ! ssh "$PI_HOST" "mountpoint -q /mnt/usbhdd && [ -n \"\$(ls -A $PI_BACKUP_DIR)\" ]"; then
        alert "Pi Backup Skipped" "$PI_HOST has no mounted drive or no backups"
        echo "ERROR: $PI_HOST:/mnt/usbhdd not mounted or $PI_BACKUP_DIR empty"
        exit 1
      fi

      mkdir -p "$BACKUP_DIR"
      rc=0
      # No --delete: the Pi prunes old snapshots and the local copy keeps them
      rsync -az "$PI_HOST:$PI_BACKUP_DIR/" "$BACKUP_DIR/" || rc=$?
      # 24 = files vanished mid-run (Pi cleanup during sync), still a usable mirror
      if [ "$rc" -ne 0 ] && [ "$rc" -ne 24 ]; then
        alert "Pi Backup Failed" "Could not reach $PI_HOST - rsync exit code $rc"
        echo "ERROR: rsync failed with exit code $rc"
        exit 1
      fi
      echo "=== Pull complete: $(du -sh "$BACKUP_DIR" | cut -f1) ==="
    '';
  };
  # Weekly pull and Proton mirror failed for months with only a notification nobody saw; this checks the result instead of the run
  watchdog = pkgs.writeShellApplication {
    name = "pi-backup-watchdog";
    runtimeInputs = with pkgs; [ findutils coreutils libnotify systemd gnugrep iputils proton-drive ];
    text = ''
      MAX_AGE_DAYS=2
      problems=""

      # -size +1k skips the 20-byte empty dumps the Pi wrote while its container name was wrong
      newest=$(find /mnt/backup/current/invoiceninja_rpi/invoiceninja -name 'db-*.sql.gz' -size +1k -printf '%T@\n' 2>/dev/null | sort -n | tail -1 | cut -d. -f1)
      if [ -z "$newest" ]; then
        problems="No usable InvoiceNinja DB dump in /mnt/backup/current/invoiceninja_rpi."
      else
        age=$(( ( $(date +%s) - newest ) / 86400 ))
        if [ "$age" -gt "$MAX_AGE_DAYS" ]; then
          problems="Newest InvoiceNinja DB dump in /mnt/backup is $age days old (pull-pi-backup)."
        fi
      fi

      # The Pi is meant to run 24/7 but has lost power for weeks at a time
      if ! ping -c 2 -W 3 raspi >/dev/null 2>&1; then
        problems="$problems raspi is not answering ping."
      fi

      # A logged-out session only shows at the next weekly run otherwise
      if ! out=$(proton-drive filesystem list /my-files 2>&1); then
        problems="$problems Proton Drive: $(echo "$out" | tail -n 1)"
      fi

      mirror_ok=$(systemctl --user show -p Result --value proton-mirror.service)
      if [ "$mirror_ok" = "success" ] && [ "$(systemctl --user show -p ActiveState --value proton-mirror.service)" = "inactive" ]; then
        finished=$(systemctl --user show -p InactiveEnterTimestamp --value proton-mirror.service)
        if [ -n "$finished" ] && [ $(( ( $(date +%s) - $(date -d "$finished" +%s) ) / 86400 )) -gt 9 ]; then
          problems="$problems proton-mirror has not completed since $finished."
        fi
      fi

      for unit in pull-pi-backup proton-mirror; do
        if [ "$(systemctl --user show -p Result --value "$unit.service")" != "success" ]; then
          problems="$problems $unit.service last run failed."
        fi
      done

      if [ -n "$problems" ]; then
        echo "ALERT:$problems"
        notify-send -u critical -t 0 "Backups are stale" "$problems" || true
        exit 1
      fi
      echo "ok: newest usable dump is $age days old, pull and mirror last runs succeeded"
    '';
  };
in
{
  home.packages = [ pullScript watchdog ];

  systemd.user.services.pi-backup-watchdog = {
    Unit.Description = "Alert when the Pi backup pull or Proton mirror has gone stale";
    # after days off, both timers catch up at once: check after the pull, not before it
    Unit.After = [ "pull-pi-backup.service" ];
    Service = {
      Type = "oneshot";
      ExecStart = "${watchdog}/bin/pi-backup-watchdog";
    };
  };

  systemd.user.timers.pi-backup-watchdog = {
    Unit.Description = "Daily backup staleness check";
    Timer = {
      OnCalendar = "*-*-* 12:00:00";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.pull-pi-backup = {
    Unit = {
      Description = "Pull InvoiceNinja backups from Raspberry Pi";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pullScript}/bin/pull-pi-backup";
      Environment = "SSH_AUTH_SOCK=%t/ssh-agent";
    };
  };

  systemd.user.timers.pull-pi-backup = {
    Unit = {
      Description = "Daily Pi backup pull timer";
    };
    Timer = {
      # Daily, after the Pi's 02:00 dump, so a dead Pi drive costs a day at most; Sunday's run lands before the Proton mirror (Sun 08:00)
      OnCalendar = "*-*-* 03:45:00";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
