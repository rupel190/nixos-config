{ pkgs, ... }:
let
  # Gatus does the checking, on the Pi (hosts/raspi/health.nix)
  gatus = "http://10.0.0.10:8083";

  # every Gatus check as a line, grouped as in its config: ✓ name and response time, or ✗ and why
  health = pkgs.writeShellApplication {
    name = "panel-health";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      if ! json=$(curl -sf -m 5 ${gatus}/api/v1/endpoints/statuses); then
        printf '\e[31m✗ gatus does not answer at %s\e[0m\n' ${gatus}
        exit 0
      fi
      jq -r '
        def pad(n): . + (" " * ([n - length, 0] | max));
        ["media", "pi", "network", "dashboard"] as $order
        | group_by(.group)
        | sort_by(.[0].group as $g | ($order | index($g)) // 99)[]
        | "\u001b[1m\(.[0].group | ascii_upcase)\u001b[0m",
          (.[] | (.results | last) as $r
            | if $r == null then "  \u001b[2m· \(.name)\u001b[0m"
              elif $r.success then "  \u001b[32m✓\u001b[0m \(.name | pad(20))\u001b[2m\($r.duration / 1000000 | floor) ms\u001b[0m"
              else "  \u001b[31m✗ \(.name | pad(20))\u001b[0m\u001b[2m\(($r.errors // []) | first // "failed" | .[0:60])\u001b[0m"
              end),
          ""
      ' <<<"$json"
    '';
  };

  # amanita's backup jobs (all user timers) with last and next run, and the newest Pi dumps
  backups = pkgs.writeShellApplication {
    name = "panel-backups";
    runtimeInputs = [
      pkgs.systemd
      pkgs.coreutils
      pkgs.findutils
      pkgs.util-linux
    ];
    text = ''
      now=$(date +%s)
      rel() { # seconds since the epoch -> "3h ago" / "in 21h"
        local d=$(( $1 - now )) w="ago" n
        if [ "$d" -gt 0 ]; then w="in"; else d=$(( -d )); fi
        if [ "$d" -lt 3600 ]; then n="$(( d / 60 ))m"
        elif [ "$d" -lt 172800 ]; then n="$(( d / 3600 ))h"
        else n="$(( d / 86400 ))d"; fi
        if [ "$w" = in ]; then echo "in $n"; else echo "$n ago"; fi
      }
      stamp() { systemctl --user show --timestamp=unix -p "$2" --value "$1" | tr -d @; }

      printf '\e[1mJOBS\e[0m                last       next\n'
      for job in "pull-pi-backup:pi pull" "pi-backup-watchdog:pi watchdog" "router-backup:router" \
                 "rsync-backups:home snapshots" "proton-mirror:proton mirror" "claude-sync-push:claude sync"; do
        unit=''${job%%:*} label=''${job#*:}
        last=$(stamp "$unit.timer" LastTriggerUSec) next=$(stamp "$unit.timer" NextElapseUSecRealtime)
        ended=$(stamp "$unit.service" ExecMainExitTimestamp)
        result=$(systemctl --user show -p Result --value "$unit.service")
        # a service that has not run since boot still reports Result=success; say so instead
        if [ -z "$ended" ]; then mark='\e[2m·\e[0m'
        elif [ "$result" = success ]; then mark='\e[32m✓\e[0m'
        else mark="\e[31m✗ $result\e[0m"; fi
        printf "$mark %-17s \e[2m%-10s %s\e[0m\n" "$label" "$([ -n "$last" ] && rel "$last" || echo never)" "$([ -n "$next" ] && rel "$next" || echo -)"
      done

      printf '\n\e[1mPI BACKUPS\e[0m (newest)\n'
      pulled=/mnt/backup/current/invoiceninja_rpi
      for app in invoiceninja splitpro paperless; do
        if [ "$app" = paperless ]; then
          # a folder export, not a dump: its manifest is rewritten every night
          newest=$(stat -c %Y "$pulled/paperless/manifest.json" 2>/dev/null || true)
        else
          # -size +1k skips empty dumps from a failed dump command
          newest=$(find "$pulled/$app" -name 'db-*.sql.gz' -size +1k -printf '%T@\n' 2>/dev/null | sort -n | tail -1 | cut -d. -f1)
        fi
        if [ -z "$newest" ]; then printf '\e[31m✗ %-17s none\e[0m\n' "$app"; continue; fi
        if [ $(( (now - newest) / 86400 )) -gt 2 ]; then c=31 m=✗; else c=32 m=✓; fi
        printf "\e[''${c}m$m\e[0m %-17s \e[2m%s\e[0m\n" "$app" "$(rel "$newest")"
      done

      # space is on mirador's disk panel; only say why everything above went red
      if ! mountpoint -q /mnt/backup; then
        printf '\n\e[31m✗ /mnt/backup is not mounted\e[0m\n'
      fi
    '';
  };

  failedUnits = pkgs.writeShellApplication {
    name = "panel-failed-units";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      f=$(systemctl --failed --no-legend --plain; systemctl --user --failed --no-legend --plain)
      if [ -n "$f" ]; then printf '\e[31m%s\e[0m\n' "$f"; else printf '\e[32m✓\e[0m none, system or user\n'; fi
    '';
  };

  # firewall, DNS, VPN and sessions, all readable without root
  security = pkgs.writeShellApplication {
    name = "panel-security";
    runtimeInputs = [
      pkgs.systemd
      pkgs.gawk
      pkgs.iproute2
    ];
    text = ''
      fw=$(systemctl is-active firewall.service || true)
      if [ "$fw" = active ]; then c=32; else c=31; fi
      printf 'firewall  \e[%sm%s\e[0m\n' "$c" "$fw"
      echo "dns       $(awk '/^nameserver/ {printf "%s ", $2}' /etc/resolv.conf)"
      echo "vpn       $(ip -br addr | awk '$1 ~ /^(zt|wg|tun|proton)/ {printf "%s %s  ", $1, $3}')"
      echo "sessions"
      loginctl list-sessions --no-legend | awk '$6 != "manager" {print "  " $3, $4, $7}'
    '';
  };
in
{
  # Plain-text panels for mirador (through mirador-run); any terminal dashboard can show them
  home.packages = [
    health
    backups
    failedUnits
    security
  ];
}
