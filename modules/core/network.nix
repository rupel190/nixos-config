{ pkgs, host, ... }:
{
  networking = {
    hostName = "${host}";
    networkmanager.enable = true;

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
}
