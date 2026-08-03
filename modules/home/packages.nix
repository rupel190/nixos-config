{ inputs, pkgs, ... }:
{
  home.packages = (
    with pkgs;
    [
      ## GUI Apps
      gimp
      imv # image viewer
      onlyoffice-desktopeditors # office alternative
      obs-studio # streaming
      oversteer # racing wheel
      wootility # Wooting keyboard configuration
      songrec # shazam-like music recognition
      digikam # photo organizer
      bitwig-studio # audio daw
      transcribe # transcribe recorded music by ear (unfree)
      qpwgraph # pipewire patchbay — visual audio routing (drag-and-drop graph)
      keepassxc
      obsidian
      # exodus — blocked: nixpkgs 26.1.5 can't be auto-downloaded; install manually or via Flatpak
      # TickTick: two RDNA 4 / NixOS rendering issues:
      # 1. libGL.so.1 unavailable → bypass EGL with ANGLE-over-Vulkan
      # 2. System RADV driver segfaults standalone → use TickTick's bundled SwiftShader Vulkan ICD
      (ticktick.overrideAttrs (_: {
        preFixup = ''
          gappsWrapperArgs+=(--add-flags "--use-gl=angle --use-angle=vulkan --enable-features=VulkanFromANGLE,DefaultANGLEVulkan")
          gappsWrapperArgs+=(--set VK_ICD_FILENAMES "$out/opt/ticktick/vk_swiftshader_icd.json")
        '';
      }))
      evince # (gnome) pdf reader
      blockbench # low-poly 3D modeling and animation
      godot_4
      freecad # CAD
      openscad-unstable # parametric CAD (2026 master; 2021.01 fails GLEW link)
      (inkscape-with-extensions.override {
        inkscapeExtensions = [ inkscape-extensions.inkstitch ];
      })
      orca-slicer
      # Communication
      signal-desktop
      element-desktop
      slack
      teams-for-linux
      teamspeak6-client # Upgraded from teamspeak3 to avoid qtwebengine build issues

      # Utility
      proton-vpn
      cryptomator
      chromium
      pureref # Reference image viewer
      bluez # Bluetooth stack
      protontricks
      wakeonlan
      zerotierone # virtual ethernet for external access
      gamescope # Gaming compositor

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

      ## CLI utility
      vicinae # everything launcher (Raycast-style)
      duf # disk usage/free utility
      eza # ls replacement
      fd # find replacement
      ffmpeg
      # Webcam controls (OBSBOT Meet 2) — UVC has no Linux vendor app; these cover it:
      v4l-utils # v4l2-ctl CLI: standard controls (brightness/gain/exposure/WB), set live mid-call
      cameractrls # decodes OBSBOT vendor Extension Unit: color_preset + on-camera save/load presets
      guvcview # GTK GUI: sliders + live preview (use between calls — needs exclusive camera stream)
      ddcutil # monitor controls over DDC/CI; DP monitors sit on the AUX bus, so trust `detect` over sysfs
      gifsicle # gif utility
      gtrash # rm replacement, put deleted files in system trash
      jq # JSON processor
      killall
      man-pages # extra man pages

      # Nix tools
      nixd # nix lsp
      nixfmt # nix formatter
      deadnix # find unused nix code
      statix # nix linter

      # Dev tools
      tree-sitter # treesitter CLI
      nodejs # Node.js runtime
      yarn # JS package manager
      bun # fast JS runtime, bundler & package manager
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
      ripdrag # Drag-and-drop from CLI
      mediainfo # Media file info for yazi
      evtest # check input events

      # Screenshot & recording
      grim # Screenshot tool
      slurp # Region selector
      swappy # snapshot editing tool
      gpu-screen-recorder # Portal-aware GPU-accelerated screen recorder

      ## CLI
      kitty # fallback
      cbonsai # terminal screensaver
      pipes # terminal screensaver
      tty-clock # cli clock
      fortune-kind # curated, kinder fortune (rust)

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
      unrar
      valgrind # c memory analyzer
      wl-clipboard # clipboard utils for wayland (wl-copy, wl-paste)
      wget
      xdg-utils

      # Arduino
      arduino-cli # compile + flash without Arduino IDE
      minicom # serial monitor (Ctrl-A X to exit)

      # C / C++
      gcc
      gdb
      gnumake

      # Python
      python3
      python312Packages.ipython
      uv # Python package manager / tool runner

      # LSPs (Language Servers)
      pyright # Python type checker LSP
      vscode-langservers-extracted # json, html, css, etc
      marksman # Markdown LSP
      taplo # TOML LSP
      lua-language-server
      bash-language-server
      typescript-language-server
      svelte-language-server
      yaml-language-server
      dockerfile-language-server
      openscad-lsp # OpenSCAD parametric 3D modeling

      # Formatters
      stylua # Lua formatter
      sqlfluff # SQL linter + formatter
      clang-tools # clang-format for C/C++
      ruff # Python linter + formatter
      prettier # Multi-language formatter
      mermaid-cli # Mermaid diagrams
    ]
  );

  services.swaync.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

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
