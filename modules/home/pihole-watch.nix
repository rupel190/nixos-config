{ pkgs, ... }:
let
  pihole = "10.0.0.10";
  router = "10.0.0.1";

  # The router sends DNS to the Pi-hole first and falls back to Cloudflare, so an outage is silent; this makes it loud
  watchScript = pkgs.writeShellApplication {
    name = "pihole-watch";
    runtimeInputs = with pkgs; [ dnsutils libnotify coreutils gnugrep ];
    text = ''
      state="''${XDG_RUNTIME_DIR:-/tmp}/pihole-problem"
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

      [ "$problem" = "$(cat "$state" 2>/dev/null || true)" ] && exit 0
      if [ -n "$problem" ]; then
        echo "$problem" > "$state"
        notify-send -u critical -t 0 "$problem" "$detail"
      else
        rm -f "$state"
        notify-send "Pi-hole is back" "Ad blocking is on again"
      fi
    '';
  };
in
{
  home.packages = [ watchScript ];

  systemd.user.services.pihole-watch = {
    Unit.Description = "Notify when the Pi-hole stops answering or blocking";
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
