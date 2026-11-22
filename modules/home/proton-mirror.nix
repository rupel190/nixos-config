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
      # At boot the notification daemon may not be up yet; a failed notify must not end the run unlogged
      notify() { echo "''${*: -2}"; notify-send "$@" || true; }
      # A boot-time catch-up starts before /mnt/backup is mounted and the network answers: wait up to 10 min
      for _ in $(seq 20); do
        if mountpoint -q /mnt/backup && out=$(proton-drive filesystem list /my-files 2>&1); then
          ok=1
          break
        fi
        ok=0
        # a lone "login first" can be a keyring read that came back empty; a real logout just waits out the 10 min
        case "''${out:-}" in *"Invalid access token"*) break ;; esac
        sleep 30
      done
      # An expired session otherwise surfaces as thousands of per-call failures
      if [ "$ok" -ne 1 ]; then
        echo "''${out:-/mnt/backup is not mounted}"
        case "''${out:-}" in
          *"login first"* | *"Invalid access token"*) notify -u critical -t 0 "Proton mirror: logged out" "run: proton-drive auth login" ;;
          "") notify -u critical -t 0 "Proton mirror failed" "/mnt/backup is not mounted" ;;
          *) notify -u critical -t 0 "Proton mirror: Drive unreachable" "$(echo "$out" | tail -n 1)" ;;
        esac
        exit 1
      fi
      rc=0
      python3 ${./proton-drive/mirror.py} || rc=$?
      case "$rc" in
        0) notify "Proton mirror complete" "/mnt/backup/current → Proton Drive /my-files/backup" ;;
        3) notify -u critical -t 0 "Proton mirror: logged out mid-run" "run: proton-drive auth login" ;;
        *) notify -u critical -t 0 "Proton mirror failed" "see: journalctl --user -u proton-mirror" ;;
      esac
      exit "$rc"
    '';
  };
in
{
  home.packages = [ mirror ];

  # Weekly after rsync-backups (Sun 04:00); a still-running snapshot is harmless, `latest` only moves when it finishes.
  systemd.user.services.proton-mirror = {
    Unit.Description = "Mirror /mnt/backup/current to Proton Drive";
    # A run lasts hours to days: never restart it on activation (HM would block until it ends, then time out)
    Unit.X-RestartIfChanged = false;
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
