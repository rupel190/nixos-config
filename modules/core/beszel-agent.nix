let
  # amanita runs the Beszel hub (hosts/amanita/health.nix) until the Pi takes over
  hub = "10.0.0.20";
in
{
  # Beszel agent on every machine; the hub dials in on 45876 and pulls CPU, RAM, temps, disks, GPU and systemd units
  services.beszel.agent = {
    enable = true;
    # the hub's public key from Add System; only the hub's private half can connect, so it's fine in the repo
    environment.KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPrLP1o+Zn4S0mz2CoesVkgmNi5/5HpXojgasEuZcsui";
  };
  # only the hub may dial in, also on foreign Wi-Fi; on amanita itself it arrives over loopback
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p tcp -s ${hub} --dport 45876 -j nixos-fw-accept
  '';
}
