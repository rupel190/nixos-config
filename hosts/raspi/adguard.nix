{ pkgs, ... }:
let
  router = "10.0.0.1";

  # Sets the web page's login inside AdGuard's own file (kept across starts by mutableSettings), so the
  # password and its hash never enter this repo: ssh -t raspi sudo adguard-login
  login = pkgs.writeShellApplication {
    name = "adguard-login";
    runtimeInputs = with pkgs; [
      mkpasswd
      yq-go
      systemd
    ];
    text = ''
      f=/var/lib/AdGuardHome/AdGuardHome.yaml
      if [ ! -w "$f" ]; then echo "run it as root: sudo adguard-login" >&2; exit 1; fi
      read -rp "user name [rupel]: " name
      name=''${name:-rupel}
      read -rsp "password: " pw; echo
      read -rsp "again: " pw2; echo
      if [ -z "$pw" ] || [ "$pw" != "$pw2" ]; then echo "empty or not the same, nothing changed" >&2; exit 1; fi
      hash=$(printf '%s' "$pw" | mkpasswd -m bcrypt -R 10 -s)
      # stopped while editing, so AdGuard cannot write its own copy over the change
      systemctl stop adguardhome
      NAME=$name HASH=$hash yq -i '.users = [{"name": strenv(NAME), "password": strenv(HASH)}]' "$f"
      systemctl start adguardhome
      echo "login set for $name"
    '';
  };
in
{
  environment.systemPackages = [ login ];

  # AdGuard Home in place of Pi-hole, with what Pi-hole had: one blocklist, its upstreams, local names
  # and reverse lookups from the router, blocked names answered with 0.0.0.0 / ::
  services.adguardhome = {
    enable = true;
    host = "0.0.0.0";
    # Pi-hole's old web port, so bookmarks keep working
    port = 8080;
    openFirewall = true;
    # merged into AdGuard's own file on every start, so what only lives there stays: the login,
    # which is why its password hash never enters this repo
    mutableSettings = true;
    settings = {
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;
        upstream_dns = [
          "1.1.1.1"
          "2606:4700:4700::1111"
          "208.67.220.220"
          "2620:119:53::53"
          # local names to the router, like Pi-hole's conditional forwarding
          "[/lan/]${router}"
        ];
        bootstrap_dns = [
          "1.1.1.1"
          "208.67.220.220"
        ];
        local_ptr_upstreams = [ router ];
        use_private_ptr_resolvers = true;
        # every LAN query comes through the router's dnsmasq: the per-client limit (20/s) would throttle all of them
        ratelimit_whitelist = [ router ];
        enable_dnssec = false;
      };
      filtering = {
        protection_enabled = true;
        filtering_enabled = true;
        blocking_mode = "null_ip";
        # answered here without going upstream, as Pi-hole did: amanita's pihole-watch asks it
        rewrites_enabled = true;
        rewrites = [
          {
            domain = "pi.hole";
            answer = "10.0.0.10";
            enabled = true;
          }
        ];
      };
      # every lookup in the house, kept about as long as Pi-hole did (91 days)
      querylog = {
        file_enabled = true;
        interval = "2160h";
      };
      filters = [
        {
          enabled = true;
          url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts";
          name = "StevenBlack hosts";
          id = 1;
        }
      ];
    };
  };

  # its settings, login and query history on the USB disk like every app's data, so the SD card only
  # holds the system and a dead card loses nothing
  fileSystems."/var/lib/private/AdGuardHome" = {
    device = "/mnt/usbhdd/apps/adguardhome";
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
    depends = [ "/mnt/usbhdd" ];
  };
  systemd.services.adguardhome.unitConfig.RequiresMountsFor = "/var/lib/private/AdGuardHome";

  networking.firewall.allowedTCPPorts = [ 53 ];
  networking.firewall.allowedUDPPorts = [ 53 ];
}
