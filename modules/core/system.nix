{
  self,
  pkgs,
  lib,
  inputs,
  host,
  ...
}:
{
  nixpkgs.overlays = [
    inputs.affinity-nix.overlays.default

    # Hyprland carrying our local fixes (both still unfixed in 0.56.0). Kept under
    # the -mirrorfix name because two modules consume it; see patches/ for the why.
    #   mirror-weakptr:         damageMirrorsWith() derefs m_mirrors entries — weak
    #                           refs — without checking expiry, so unplugging a
    #                           mirrored output kills the session on the next frame.
    #   idle-inhibit-noop-reset: setInhibit() resets every idle notification even
    #                           when the inhibit state is unchanged, so any window
    #                           map/unmap/focus rewinds the idle clock — Steam toasts
    #                           relight a blanked, locked session hours later.
    # Consumed by modules/core/wayland.nix and modules/home/hyprland.
    # NOTE: patching defeats the hyprland.cachix.org hit below, so Hyprland is a
    # local compile until upstream lands these and they can be dropped.
    (_final: prev: {
      hyprland-mirrorfix =
        inputs.hyprland.packages.${prev.stdenv.hostPlatform.system}.default.overrideAttrs
          (old: {
            patches = (old.patches or [ ]) ++ [
              ../../patches/hyprland-mirror-weakptr.patch
              ../../patches/hyprland-idle-inhibit-noop-reset.patch
            ];
          });
    })
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
        # Hyprland, hyprland-plugins and xdph come from git inputs, which nixpkgs
        # never builds. An input flake's own nixConfig does NOT apply to us, so
        # without this every Hyprland bump is a local C++ compile on both hosts.
        "https://hyprland.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
    };
  };

  environment.systemPackages =
    (with pkgs; [
      wget
      git
      pkgs.ragenix
    ])
    # amanita only: a 2.8 GB Wine prefix + 1.5 GB of sources, and cache.garnix.io
    # is not resolving, so it builds locally rather than substituting.
    ++ lib.optionals (host == "amanita") [
      pkgs.affinity-v3 # unified Affinity suite via affinity-nix (wine); needs your own installer on first run
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
      "24273a"
      "ed8796"
      "a6da95"
      "eed49f"
      "8aadf4"
      "f5bde6"
      "8bd5ca"
      "b8c0e0"
      "5b6078"
      "ed8796"
      "a6da95"
      "eed49f"
      "8aadf4"
      "f5bde6"
      "8bd5ca"
      "a5adcb"
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
