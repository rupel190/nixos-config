{ inputs, pkgs, ... }:
let
  _2048 = pkgs.callPackage ../../pkgs/2048/default.nix { };
in
{
  home.packages = (
    with pkgs;
    [
      _2048

      ## CLI utility
      ani-cli
      binsider
      bitwise # cli tool for bit / hex manipulation
      caligula # User-friendly, lightweight TUI for disk imaging
      dconf-editor
      docfd # TUI multiline fuzzy document finder
      eza # ls replacement
      entr # perform action when file change
      fd # find replacement
      ffmpeg
      file # Show file information
      gtt # google translate TUI
      gifsicle # gif utility
      gtrash # rm replacement, put deleted files in system trash
      hexdump
      htop
      imv # image viewer
      jq # JSON processor
      killall
      libnotify
      man-pages # extra man pages
      mimeo
      ncdu # disk space
      nitch # systhem fetch util
      nixd # nix lsp
      nixfmt-rfc-style # nix formatter
      openssl
      onefetch # fetch utility for git repo
      pamixer # pulseaudio command line mixer
      playerctl # controller for media players
      poweralertd
      programmer-calculator
      ripgrep # grep replacement
      shfmt # bash formatter
      swappy # snapshot editing tool
      tdf # cli pdf viewer
      treefmt2 # project formatter
      tldr
      todo # cli todo list
      toipe # typing test in the terminal
      ttyper # cli typing test
      unzip
      valgrind # c memory analyzer
      wavemon # monitoring for wireless network devices
      wl-clipboard # clipboard utils for wayland (wl-copy, wl-paste)
      wget
      woomer
      yt-dlp-light
      xdg-utils
      xxd

      # Gnome
      evince # pdf reader

      ## CLI
      kitty # fallback
      cbonsai # terminal screensaver
      cmatrix
      pipes # terminal screensaver
      sl
      pulsemixer
      tty-clock # cli clock

      ## GUI Apps
      fuzzel # launcher
      audacity
      bleachbit # cache cleaner
      gimp
      onlyoffice
      nix-prefetch-github
      obs-studio
      pitivi # video editing
      resources # GUI resources monitor
      soundwireserver
      vlc
      winetricks
      wineWowPackages.wayland
      zenity

      # C / C++
      gcc
      gdb
      gnumake

      # Zig
      inputs.zig.packages.${system}.master
      zls

      # Python
      python3
      python312Packages.ipython

      inputs.alejandra.defaultPackage.${system}
    ]
  );
}
