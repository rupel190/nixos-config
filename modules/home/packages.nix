{ inputs, pkgs, ... }:
{
  home.packages = (
    with pkgs;
    [
      ## CLI utility
      eza # ls replacement
      fd # find replacement
      ffmpeg
      gifsicle # gif utility
      gtrash # rm replacement, put deleted files in system trash
      jq # JSON processor
      killall
      man-pages # extra man pages

      nixd # nix lsp
      nixfmt-rfc-style # nix formatter

      openssl
      ripgrep # grep replacement
      shfmt # bash formatter
      swappy # snapshot editing tool
      tdf # cli pdf viewer
      treefmt2 # project formatter
      tldr
      toipe # typing test in the terminal
      ttyper # cli typing test
      unzip
      valgrind # c memory analyzer
      wl-clipboard # clipboard utils for wayland (wl-copy, wl-paste)
      wget
      xdg-utils

      # Gnome
      evince # pdf reader

      ## CLI
      kitty # fallback
      cbonsai # terminal screensaver
      cmatrix
      pipes # terminal screensaver
      pulsemixer
      tty-clock # cli clock

      ## GUI Apps
      fuzzel # launcher
      gimp
      oculante # image viewer
      onlyoffice
      obs-studio
      winetricks
      wineWowPackages.wayland

      # C / C++
      gcc
      gdb
      gnumake

      # Python
      python3
      python312Packages.ipython

      # Additional user packages
      digikam
      bitwig-studio
      betterdiscordctl
    ]
  );

  # Virt-manager dconf settings
  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
  };
}
