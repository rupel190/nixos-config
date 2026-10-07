{ pkgs, ... }:
let
  pullScript = pkgs.writeShellApplication {
    name = "pull-pi-backup";
    runtimeInputs = with pkgs; [ rsync openssh libnotify coreutils util-linux ];
    # Backups stay local: the tree includes InvoiceNinja's .env and DB dumps, never copy them to OneDrive.
    text = ''
      BACKUP_DIR="/mnt/backup/invoiceninja_rpi"
      PI_HOST="raspi5"
      PI_BACKUP_DIR="/mnt/usbhdd/backups"

      echo "=== Pi Backup Pull: $(date) ==="
      if ! mountpoint -q /mnt/backup; then
        notify-send -u critical "Pi Backup Failed" "/mnt/backup is not mounted"
        exit 1
      fi

      mkdir -p "$BACKUP_DIR"
      rc=0
      rsync -az --delete "$PI_HOST:$PI_BACKUP_DIR/" "$BACKUP_DIR/" || rc=$?
      # 24 = files vanished mid-run (Pi cleanup during sync), still a usable mirror
      if [ "$rc" -ne 0 ] && [ "$rc" -ne 24 ]; then
        notify-send -u critical "Pi Backup Failed" "Could not reach $PI_HOST - rsync exit code $rc"
        echo "ERROR: rsync failed with exit code $rc"
        exit 1
      fi
      echo "=== Pull complete: $(du -sh "$BACKUP_DIR" | cut -f1) ==="
    '';
  };
in
{
  home.packages = [ pullScript ];

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
      Description = "Weekly Pi backup pull timer";
    };
    Timer = {
      OnCalendar = "Sun *-*-* 10:00:00";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
