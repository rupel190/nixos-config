{
  self,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  nixpkgs.overlays = [
    inputs.millennium.overlays.default
    inputs.affinity-nix.overlays.default
  ];

  # imports = [ inputs.nix-gaming.nixosModules.default ];
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [
        "https://cache.nixos.org"
        "https://nix-gaming.cachix.org"
        "https://cache.garnix.io" # affinity-nix prebuilt wine prefix
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    wget
    git
    pkgs.ragenix
    affinity-v3 # unified Affinity suite via affinity-nix (wine); needs your own installer on first run
  ];

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
    # Catppuccin Macchiato palette for the Linux TTY (and therefore the tuigreet login).
    # Matches the macchiato cursor theme used in Hyprland. 16 entries, hex without '#':
    # normal 0-7 then bright 8-15. Index 0 (base #24273a) doubles as the console
    # background, giving the dark Catppuccin backdrop.
    colors = [
      "24273a" "ed8796" "a6da95" "eed49f" "8aadf4" "f5bde6" "8bd5ca" "b8c0e0"
      "5b6078" "ed8796" "a6da95" "eed49f" "8aadf4" "f5bde6" "8bd5ca" "a5adcb"
    ];
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
