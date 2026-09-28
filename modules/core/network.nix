{ pkgs, host, ... }:
{
  networking = {
    hostName = "${host}";
    networkmanager.enable = true;
    # Desktop: no battery to save; a dozing Frame dongle delays headset->PC pose packets.
    networkmanager.wifi.powersave = false;

    # DNS - Leave commented to use router's settings (PiHole)
    # Only override if you need to bypass router DNS
    # nameservers = [ "8.8.8.8" "1.1.1.1" ];

    # Firewall - blocks incoming connections by default
    firewall = {
      enable = true;
      # Add ports here as needed (Steam already handled in steam.nix)
      # allowedTCPPorts = [ 80 443 ];
      # allowedUDPPorts = [ ];
    };
  };

  # World regdomain "00" disables all 6 GHz channels; the Steam Frame dongle links on 6 GHz.
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom="AT"
  '';
}
