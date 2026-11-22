{ config, ... }:
{
  # Beszel hub :8090 (machines), open to the LAN with its own login. Gatus and Glance run on the Pi
  # (hosts/raspi/health.nix); agents: modules/core/beszel-agent.nix on every NixOS machine
  services.beszel.hub = {
    enable = true;
    host = "0.0.0.0";
  };
  networking.firewall.allowedTCPPorts = [ config.services.beszel.hub.port ];
}
