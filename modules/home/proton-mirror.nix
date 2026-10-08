{ pkgs, ... }:
let
  proton-drive = pkgs.callPackage ./proton-drive/package.nix { };

  mirror = pkgs.writeShellApplication {
    name = "proton-mirror";
    runtimeInputs = [ proton-drive pkgs.python3 pkgs.libnotify pkgs.util-linux ];
    text = ''
      # One mirror at a time: a first upload can outlast the weekly timer
      exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/proton-mirror.lock"
      if ! flock -n 9; then
        echo "another proton-mirror is still running; skipping"
        exit 0
      fi
      if python3 ${./proton-drive/mirror.py}; then
        notify-send "Proton mirror complete" "/mnt/backup/current → Proton Drive /my-files/backup"
      else
        notify-send -u critical "Proton mirror failed" "see: journalctl --user -u proton-mirror"
        exit 1
      fi
    '';
  };
in
{
  home.packages = [ mirror ];

  # Weekly after rsync-backups (Sun 04:00); a still-running snapshot is harmless, `latest` only moves when it finishes.
  systemd.user.services.proton-mirror = {
    Unit.Description = "Mirror /mnt/backup/current to Proton Drive";
    Service = {
      Type = "oneshot";
      ExecStart = "${mirror}/bin/proton-mirror";
      Nice = 19;
      IOSchedulingClass = "idle";
      MemoryHigh = "4G";
    };
  };

  systemd.user.timers.proton-mirror = {
    Unit.Description = "Weekly Proton Drive mirror timer";
    Timer = {
      OnCalendar = "Sun *-*-* 08:00:00";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
