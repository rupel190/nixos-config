{ pkgs, host, ... }:
let
  # Gatus does the checking (hosts/amanita/health.nix); other machines ask amanita's over the LAN
  gatus = if host == "amanita" then "http://127.0.0.1:8083" else "http://10.0.0.20:8083";

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

  failedUnits = pkgs.writeShellApplication {
    name = "panel-failed-units";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      f=$(systemctl --failed --no-legend --plain; systemctl --user --failed --no-legend --plain)
      if [ -n "$f" ]; then printf '\e[31m%s\e[0m\n' "$f"; else printf '\e[32m✓\e[0m none, system or user\n'; fi
    '';
  };

  # firewall, DNS, VPN and sessions, all readable without root (WTF's own security module needs root
  # for the firewall and so reports "No firewall")
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
  # Plain-text panels any terminal dashboard can show: mirador through mirador-run, WTF through cmdrunner
  home.packages = [
    health
    failedUnits
    security
  ];
}
