{ pkgs, ... }:
let
  pihole = "10.0.0.10";
  router = "10.0.0.1";

  # Runs on the router: one line per recorded attempt, "device server port v4", where v4 is the device's IPv4
  # address (found via its MAC), so an IPv6 privacy address still resolves to a name
  bypassQuery = pkgs.writeText "dns-bypass-query.sh" ''
    for s in dns_bypass_v4 dns_bypass_v6; do nft list set inet fw4 "$s"; done \
      | grep -oE '[0-9a-f:.]+ \. [0-9a-f:.]+ \. [0-9]+' \
      | while read -r dev _ server _ port; do
          mac=$(ip neigh show "$dev" | grep -oE 'lladdr [0-9a-f:]+' | cut -d' ' -f2)
          v4=$(awk -v m="$mac" '$2 == m { print $3 }' /tmp/dhcp.leases | head -1)
          echo "$dev $server $port ''${v4:-$dev}"
        done
  '';

  # The router sends DNS to the Pi-hole first and falls back to Cloudflare, so an outage is silent; this makes it loud
  watchScript = pkgs.writeShellApplication {
    name = "pihole-watch";
    runtimeInputs = with pkgs; [ dnsutils libnotify coreutils gnugrep openssh ];
    text = ''
      state="''${XDG_RUNTIME_DIR:-/tmp}/pihole-problem"
      seen="''${XDG_STATE_HOME:-$HOME/.local/state}/pihole-watch/dns-bypass-seen"
      ask() { dig +short +time=3 +tries=2 "$@" | grep -q .; }

      # the router names its own address itself: no answer there means this PC is offline, not the Pi-hole
      ask @${router} -x ${router} || exit 0

      # pi.hole is answered by the Pi-hole without going upstream, so this tests the Pi-hole, not the internet
      if ! ask @${pihole} pi.hole A; then
        problem="Pi-hole is down"
        detail="No ad blocking: the router is using Cloudflare instead"
      # doubleclick.net is on every blocklist: a real address means the Pi-hole answers but lost its lists (its disk dropped out once)
      elif [ "$(dig +short +time=3 +tries=2 @${pihole} doubleclick.net A)" != "0.0.0.0" ]; then
        problem="Pi-hole is not blocking"
        detail="It answers, but ads get through"
      else
        problem=""
      fi

      if [ "$problem" != "$(cat "$state" 2>/dev/null || true)" ]; then
        if [ -n "$problem" ]; then
          echo "$problem" > "$state"
          notify-send -u critical -t 0 "$problem" "$detail"
        else
          rm -f "$state"
          notify-send "Pi-hole is back" "Ad blocking is on again"
        fi
      fi

      # The router records devices that send DNS to an outside server (/etc/nftables.d/20-dns-bypass.nft); announce each device/server pair once.
      # Its record empties on a router reboot, the seen file doesn't, so a known pair stays quiet.
      mkdir -p "$(dirname "$seen")" && touch "$seen"
      pairs=$(ssh -o BatchMode=yes -o ConnectTimeout=10 root@${router} sh -s < ${bypassQuery} 2>/dev/null || true)
      while read -r dev server port v4; do
        [ -n "$dev" ] || continue
        # keyed on the IPv4 address: IPv6 privacy addresses change daily and would announce the same device again
        grep -qxF "$v4 $server $port" "$seen" && continue
        echo "$v4 $server $port" >> "$seen"
        name=$(dig +short +time=3 @${router} -x "$v4" | head -1 || true)
        name=''${name%%.*}
        case "$server" in
          8.8.8.8 | 8.8.4.4 | 2001:4860:4860::*) who="Google DNS" ;;
          1.1.1.1 | 1.0.0.1 | 2606:4700:4700::*) who="Cloudflare DNS" ;;
          9.9.9.9 | 149.112.112.112 | 2620:fe::*) who="Quad9 DNS" ;;
          208.67.222.222 | 208.67.220.220 | 2620:119:*) who="OpenDNS" ;;
          *) who="a DNS server" ;;
        esac
        if [ "$port" = 53 ]; then
          outcome="redirected to the Pi-hole"
        elif [[ "$dev" == 10.0.100.* ]]; then
          outcome="encrypted DNS, blocked"
        else
          outcome="encrypted DNS, so it skipped the Pi-hole"
        fi
        via=""
        [[ "$dev" == *:* ]] && via=" over IPv6"
        notify-send "DNS bypass: ''${name:-$v4}" "Tried $who ($server)$via: $outcome"
      done <<< "$pairs"
    '';
  };
in
{
  home.packages = [ watchScript ];

  systemd.user.services.pihole-watch = {
    Unit.Description = "Notify when the Pi-hole stops answering or blocking, or a device tries another DNS server";
    Unit.X-RestartIfChanged = false;
    Service = {
      Type = "oneshot";
      ExecStart = "${watchScript}/bin/pihole-watch";
    };
  };

  systemd.user.timers.pihole-watch = {
    Unit.Description = "Check the Pi-hole every 2 minutes";
    Timer = {
      OnBootSec = "2min";
      OnUnitActiveSec = "2min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
