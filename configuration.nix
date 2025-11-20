{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
  ];

  # User configuration
  users.users.rupel = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
    packages = with pkgs; [ tree ];
  };

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Boot configuration
  # Kernel parameters for RX 9070 XT stability

  # Network and locale
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # Harddrives
  fileSystems."/mnt/silo" = {
    device = "/dev/disk/by-uuid/4eb8d0d5-60b4-424e-b7d9-4aeaba384849";
    fsType = "ext4";
    options = [
      "defaults"
      "nofail"
    ];
  };

  fileSystems."/mnt/gamedev" = {
    device = "/dev/disk/by-uuid/273504fb-eb69-448d-ba14-5472c43fdb8f";
    fsType = "ext4";
    options = [
      "noatime"
      "nodiratime"
      "discard"
    ]; # SSD
  };

  boot.supportedFilesystems = [
    "ntfs"
    "exfat"
  ];
  fileSystems."/mnt/bak-ntfs" = {
    device = "/dev/disk/by-uuid/44FA3809FA37F5B0";
    fsType = "ntfs";
    options = [
      "defaults"
      "nofail"
    ];
  };

  fileSystems."/mnt/bak-btrfs" = {
    device = "/dev/disk/by-uuid/2cf4acdd-ebf1-4134-8225-80b7982f68f7";
    fsType = "btrfs";
    options = [
      "noatime"
      "compress=zstd"
      "discard=async"
    ]; # SSD + btrfs-specific optimizations
  };

  fileSystems."/mnt/bak-internal" = {
    device = "/dev/disk/by-uuid/6FFF-FCF9";
    fsType = "exfat";
    options = [
      "defaults"
      "nofail"
    ];
  };

  fileSystems."/mnt/bak-external" = {
    device = "/dev/disk/by-uuid/1787c6c5-6ad8-4051-8d45-f61609e8c732";
    fsType = "ext4";
    options = [
      "defaults"
      "nofail"
    ];
  };


  # Env vars  for AMD + Wayland
  environment.variables = {
    EDITOR = "nvim";
    # Force discrete GPU (RX 9070 XT) -> Abiotic Factor would use iGPU otherwise. TODO: Crosscheck if still works when iGPU is enabled in UEFI
    DRI_PRIME = "1";
    # Use RADV (Mesa) driver for Vulkan
    AMD_VULKAN_ICD = "RADV";
    # Wayland specific
    WLR_RENDERER = "vulkan";
    # Disable shader cache issues
    MESA_SHADER_CACHE_DISABLE = "false";
  };

  # X11
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  
  # Hyprland - use NixOS module for automatic dependency management
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  };

  # Virt-manager
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = [ "rupel" ];
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

 

  system.stateVersion = "25.05";
  system.nixos.label = "testlabel:_.-"


  # Required for home-manager xdg.portal integration
  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];
  # Required for Flatpak and XDG Desktop Portal
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*"; # Use first available portal (lexicographical order)
  };

  # System packages
  environment.systemPackages = with pkgs; [
    # flakes
    inputs.zen-browser.packages."${pkgs.stdenv.hostPlatform.system}".default

    fishPlugins.done
    # fishPlugins.fzf
    fishPlugins.colored-man-pages


    # base
    vim
    neovim
    wget
    wezterm
    kitty # fallback
    fastfetch
    fuzzel
    yazi
    evince
    oculante
    mpv
    pulsemixer
    usbutils

    # nvim / lazyvim
    cargo # Rust package home-manager
    rustc # Rust compiler
    gcc # C compiler for treesitter
    jdk
    php
    nodejs
    nodePackages.prettier # Multilang formatter
    nodePackages.mermaid-cli # Mermaid diagrams (provides 'mmdc' command)
    fd # replacement for find
    # fzf
    python3 # python support for plugins
    lazygit # TUI for git operations
    imagemagick # Image processing
    ghostscript # PDF rendering

    sqlite # Improves Snacks.picker with frecency/history (otherwise uses file)
    deadnix # nix find unused code

    # treesitter
    tree-sitter # CLI is used by nvim to install treesitters

    # formatter
    statix # nix linter
    nixfmt-rfc-style # nix code formatter
    shfmt # shell formatter
    stylua # lua formatter
    sqlfluff # sql lint + fmt
    clang-tools # clang-format for c/cpp
    rustfmt
    ruff # python lint + fmt

    # lsp
    nil # nix LSP
    lua-language-server      
    bash-language-server     

    vscode-langservers-extracted  # Provides: json-language-server, html, css, etc.
    nodePackages.typescript-language-server  # TypeScript/JavaScript (vtsls alternative)
    nodePackages.svelte-language-server
    yaml-language-server    
    marksman                 # Markdown
    taplo                    # TOML
    dockerfile-language-server # Docker


    # dev / util
    ripgrep # Replacement for grep
    ripdrag
    eza # Replacement for ls
    zoxide
    git
    git-lfs
    yarn
    claude-code

    swappy
    grim
    slurp

    chezmoi
    mediainfo # Fileinfo for yazi
    wl-clipboard
    wl-screenrec
    gamescope

    # services
    onedrive

    # apps
    obsidian
    protonvpn-gui
    keepassxc
    cryptomator
    (spotify.override {
      # attempt to fix coredumps by reducing electron conflicts
      deviceScaleFactor = 1.0;
    })
    chromium
    signal-desktop
    slack
    teams-for-linux
    pureref
    cava

    # AMD-specific
    radeontop
    vulkan-tools
    mesa-demos

    # android mtp connection
    gvfs
    glib
    simple-mtpfs

    # theming
    hyprpicker
    hyprcursor
    hyprsunset
    catppuccin-cursors.macchiatoYellow
  ];

  xdg.mime.defaultApplications = {
    "x-scheme-handler/http" = "app.zen_browser.zen.desktop";
    "x-scheme-handler/https" = "io.github.zen_browser.zen.desktop";
    "text/html" = "io.github.zen_browser.zen.desktop";
  };
}
