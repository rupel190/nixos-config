{
  self,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  # imports = [ inputs.nix-gaming.nixosModules.default ];
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # Optional: Add gaming cachix if needed
      # substituters = [ "https://nix-gaming.cachix.org" ];
      # trusted-public-keys = [
      #   "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      # ];
    };
  };

  # nixpkgs.overlays = [ ]; # Add overlays here if needed

  environment.systemPackages = with pkgs; [
    wget
    git
  ];

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  nixpkgs.config = {
    allowUnfree = true;
    # Temporarily allow insecure qtwebengine for Qt5 apps
    # TODO: Identify which package needs this and find alternative
    # Likely culprits: teamspeak3, cryptomator, protonvpn-gui, keepassxc, digikam
    permittedInsecurePackages = [
      "qtwebengine-5.15.19"
    ];
  };

  system.stateVersion = "25.05";
}
