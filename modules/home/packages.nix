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

      # Nix tools
      nixd # nix lsp
      nixfmt-rfc-style # nix formatter
      deadnix # find unused nix code
      statix # nix linter

      # Dev tools
      tree-sitter # treesitter CLI
      nodejs # Node.js runtime
      yarn # JS package manager
      cargo # Rust package manager
      rustc # Rust compiler
      rustfmt # Rust formatter
      jdk # Java development kit
      php # PHP runtime
      imagemagick # Image processing
      ghostscript # PDF rendering
      sqlite # Database

      # Shell & CLI tools
      zoxide # Better cd
      vim # Classic editor
      neovim # Modern vim
      chezmoi # Dotfile manager
      ripdrag # Drag-and-drop from CLI
      mediainfo # Media file info for yazi

      # Screenshot & recording
      grim # Screenshot tool
      slurp # Region selector
      swappy # snapshot editing tool
      wl-screenrec # Screen recorder

      openssl
      ripgrep # grep replacement
      shfmt # bash formatter
      tdf # cli pdf viewer
      treefmt # project formatter
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
      onlyoffice-desktopeditors
      obs-studio
      winetricks
      wineWowPackages.wayland
      gamescope # Gaming compositor

      # Communication
      signal-desktop
      slack
      teams-for-linux
      teamspeak3

      # Utilities
      protonvpn-gui
      cryptomator
      chromium
      pureref # Reference image viewer
      bluez # Bluetooth stack

      # AMD GPU tools
      radeontop # AMD GPU monitor
      vulkan-tools # Vulkan utilities
      mesa-demos # OpenGL demos

      # Android MTP
      gvfs # Virtual filesystem
      glib # GLib library
      simple-mtpfs # MTP filesystem

      # Wayland/Hyprland theming
      hyprpicker # Color picker
      hyprcursor # Cursor manager
      hyprsunset # Blue light filter
      catppuccin-cursors.macchiatoYellow

      # C / C++
      gcc
      gdb
      gnumake

      # Python
      python3
      python312Packages.ipython

      # LSPs (Language Servers)
      lua-language-server
      bash-language-server
      vscode-langservers-extracted # json, html, css, etc
      nodePackages.typescript-language-server
      nodePackages.svelte-language-server
      yaml-language-server
      marksman # Markdown LSP
      taplo # TOML LSP
      dockerfile-language-server

      # Formatters
      stylua # Lua formatter
      sqlfluff # SQL linter + formatter
      clang-tools # clang-format for C/C++
      ruff # Python linter + formatter
      nodePackages.prettier # Multi-language formatter
      nodePackages.mermaid-cli # Mermaid diagrams

      # Additional user packages
      digikam
      bitwig-studio
      betterdiscordctl
      keepassxc
      obsidian
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
