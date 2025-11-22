{ pkgs, username, ... }:
{
  # nh - NixOS helper tool with prettier output and auto-cleanup
  # Usage: 'nh os switch' instead of 'nixos-rebuild switch'
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep-since 7d --keep 5";
    };
    flake = "/home/${username}/projects/nixos-config";
  };

  environment.systemPackages = with pkgs; [
    nix-output-monitor # Pretty build output
    nvd # Nix version diff tool
  ];
}
