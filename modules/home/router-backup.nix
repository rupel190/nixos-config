{ pkgs, ... }:
let
  router = "root@10.0.0.1";
  dest = "/mnt/backup/current/router";
  keep = 8;

  # sysupgrade -b = LuCI's "Backup / Flash Firmware" archive (/etc/config and friends); restorable there
  backupScript = pkgs.writeShellApplication {
    name = "router-backup";
    runtimeInputs = with pkgs; [ openssh coreutils findutils util-linux libnotify ];
    text = ''
      umask 077 # the archive holds the WiFi key and the root password hash
      if ! mountpoint -q /mnt/backup; then
        notify-send -u critical "Router backup failed" "/mnt/backup is not mounted"
        exit 1
      fi
      mkdir -p ${dest}
      date=$(date +%Y-%m-%d)
      ssh_r() { ssh -o BatchMode=yes -o ConnectTimeout=10 ${router} "$@"; }

      if ! ssh_r 'sysupgrade -b -' > "${dest}/openwrt-$date.tar.gz.part"; then
        rm -f "${dest}/openwrt-$date.tar.gz.part"
        notify-send -u critical "Router backup failed" "ssh ${router} sysupgrade -b"
        exit 1
      fi
      mv "${dest}/openwrt-$date.tar.gz.part" "${dest}/openwrt-$date.tar.gz"
      # the archive holds config only; the package list says what to reinstall
      ssh_r 'apk info 2>/dev/null || opkg list-installed' > "${dest}/packages-$date.txt" || true

      find ${dest} -name 'openwrt-*.tar.gz' | sort | head -n -${toString keep} | xargs -r rm -f
      find ${dest} -name 'packages-*.txt' | sort | head -n -${toString keep} | xargs -r rm -f
      echo "router backup: ${dest}/openwrt-$date.tar.gz"
    '';
  };
in
{
  home.packages = [ backupScript ];

  systemd.user.services.router-backup = {
    Unit.Description = "Back up the OpenWrt router config to /mnt/backup";
    Unit.X-RestartIfChanged = false;
    Service = {
      Type = "oneshot";
      ExecStart = "${backupScript}/bin/router-backup";
    };
  };

  # Before rsync-backups (04:00) and the Proton mirror (08:00), so the mirror carries it
  systemd.user.timers.router-backup = {
    Unit.Description = "Weekly OpenWrt router backup";
    Timer = {
      OnCalendar = "Sun *-*-* 03:30:00";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
