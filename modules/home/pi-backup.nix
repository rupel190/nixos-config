{ pkgs, ... }:
let
  pullScript = pkgs.writeShellApplication {
    name = "pull-pi-backup";
    runtimeInputs = with pkgs; [ rsync zip openssh libnotify coreutils findutils ];
    text = ''
      SILO_DIR="/mnt/silo/invoiceninja_rpi"
      ONEDRIVE_DIR="$HOME/OneDrive/Backups/InvoiceNinja"
      PI_HOST="raspi5"
      PI_BACKUP_DIR="/mnt/usbhdd/backups"

      echo "=== Pi Backup Pull: $(date) ==="

      # Mirror full backup tree to silo (fail = notify + exit)
      echo "Syncing backups to silo..."
      mkdir -p "$SILO_DIR"
      rc=0
      rsync -az --delete "$PI_HOST:$PI_BACKUP_DIR/" "$SILO_DIR/" || rc=$?
      if [ "$rc" -ne 0 ] && [ "$rc" -ne 24 ]; then
        # rc=24 means "some files vanished" (Pi cleanup during sync) - that's fine
        notify-send -u critical "Pi Backup Failed" "Could not reach $PI_HOST - rsync exit code $rc"
        echo "ERROR: rsync failed with exit code $rc"
        exit 1
      fi
      echo "Silo sync complete: $(du -sh "$SILO_DIR" | cut -f1)"

      # Build a single zip of the latest backup for OneDrive
      echo "Creating OneDrive zip..."
      mkdir -p "$ONEDRIVE_DIR"

      TMPDIR=$(mktemp -d)
      trap 'rm -rf "$TMPDIR"' EXIT

      LATEST_DB=$(find "$SILO_DIR/invoiceninja" -name 'db-*.sql.gz' -printf '%T@\t%p\n' 2>/dev/null | sort -rn | head -1 | cut -f2)
      LATEST_FILES=$(find "$SILO_DIR/invoiceninja" -name 'files-*.tar.gz' -printf '%T@\t%p\n' 2>/dev/null | sort -rn | head -1 | cut -f2)
      LATEST_CONFIG=$(find "$SILO_DIR/configs" -name 'invoiceninja-config-*.tar.gz' -printf '%T@\t%p\n' 2>/dev/null | sort -rn | head -1 | cut -f2)

      [ -n "''${LATEST_DB:-}" ] && cp "$LATEST_DB" "$TMPDIR/"
      [ -n "''${LATEST_FILES:-}" ] && cp "$LATEST_FILES" "$TMPDIR/"
      [ -n "''${LATEST_CONFIG:-}" ] && cp "$LATEST_CONFIG" "$TMPDIR/"

      cd "$TMPDIR"
      zip -j "$ONEDRIVE_DIR/invoiceninja-latest.zip" ./*

      echo "OneDrive zip: $(du -h "$ONEDRIVE_DIR/invoiceninja-latest.zip" | cut -f1)"
      echo "=== Pull complete ==="
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
