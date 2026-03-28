{ inputs, pkgs, ... }:
{
  home.packages = (
    with pkgs;
    [
      ## GUI Apps
      fuzzel # launcher
      gimp
      imv # image viewer
      onlyoffice-desktopeditors # office alternative
      obs-studio # streaming
      oversteer # racing wheel
      digikam # photo organizer
      bitwig-studio # audio daw
      keepassxc
      obsidian
      evince # (gnome) pdf reader
      blockbench # low-poly 3D modeling and animation
      freecad # CAD
      openscad # parametric CAD
      (inkscape-with-extensions.override {
        inkscapeExtensions = [ inkscape-extensions.inkstitch ];
      })
      orca-slicer
      # Plasticity: Linux version has broken UI (unit picker, preferences, dropdowns)
      # on non-Ubuntu distros — https://github.com/NixOS/nixpkgs/issues/403992
      # Using Windows version via Wine instead (installed at ~/.wine/drive_c/Program Files/Plasticity/)

      # Communication
      signal-desktop
      element-desktop
      slack
      teams-for-linux
      teamspeak6-client # Upgraded from teamspeak3 to avoid qtwebengine build issues

      # Utility
      protonvpn-gui
      cryptomator
      chromium
      pureref # Reference image viewer
      bluez # Bluetooth stack
      wineWowPackages.staging # prebuilt wine
      protontricks
      winetricks
      wakeonlan
      zerotierone # virtual ethernet for external access
      # gamescope # Gaming compositor

      # Tweaks
      betterdiscordctl

      # Android MTP
      gvfs # Virtual filesystem
      glib # GLib library
      simple-mtpfs # MTP filesystem

      # AMD GPU util
      radeontop # AMD GPU monitor
      vulkan-tools # Vulkan utilities
      mesa-demos # OpenGL demos

      # Wayland/Hyprland theming
      hyprpicker # Color picker
      hyprcursor # Cursor manager
      hyprsunset # Blue light filter
      hyprnotify # Notification daemon using hyprctl notify
      catppuccin-cursors.macchiatoYellow

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

      ## CLI
      kitty # fallback
      cbonsai # terminal screensaver
      cmatrix
      pipes # terminal screensaver
      pulsemixer
      tty-clock # cli clock

      openssl
      ripgrep # grep replacement
      shfmt # bash formatter
      tdf # cli pdf viewer
      treefmt # project formatter
      tldr
      toipe # typing test in the terminal
      ttyper # cli typing test
      zip
      unzip
      valgrind # c memory analyzer
      wl-clipboard # clipboard utils for wayland (wl-copy, wl-paste)
      wget
      xdg-utils

      # C / C++
      gcc
      gdb
      gnumake

      # Python
      python3
      python312Packages.ipython

      # LSPs (Language Servers)
      pyright # Python type checker LSP
      vscode-langservers-extracted # json, html, css, etc
      marksman # Markdown LSP
      taplo # TOML LSP
      lua-language-server
      bash-language-server
      nodePackages.typescript-language-server
      nodePackages.svelte-language-server
      yaml-language-server
      dockerfile-language-server
      openscad-lsp # OpenSCAD parametric 3D modeling

      # Formatters
      stylua # Lua formatter
      sqlfluff # SQL linter + formatter
      clang-tools # clang-format for C/C++
      ruff # Python linter + formatter
      nodePackages.prettier # Multi-language formatter
      nodePackages.mermaid-cli # Mermaid diagrams
    ]
  );

  xdg.configFile."imv/config".text = ''
    [binds]
    j = next_image
    k = prev_image
    h = prev_image
    l = next_image
    <left> = pan -10 0
    <right> = pan 10 0
    <up> = pan 0 -10
    <down> = pan 0 10
    , = rotate -90
    . = rotate 90
  '';

  # Virt-manager dconf settings
  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
  };
}
