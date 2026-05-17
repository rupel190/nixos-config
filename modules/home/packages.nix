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
      wootility # Wooting keyboard configuration
      digikam # photo organizer
      bitwig-studio # audio daw
      keepassxc
      obsidian
      exodus
      # TickTick: two RDNA 4 / NixOS rendering issues:
      # 1. libGL.so.1 unavailable → bypass EGL with ANGLE-over-Vulkan
      # 2. System RADV driver segfaults standalone (works in gamescope like Plasticity, not standalone)
      #    → use TickTick's own bundled SwiftShader Vulkan ICD instead of the system driver
      (ticktick.overrideAttrs (_: {
        preFixup = ''
          gappsWrapperArgs+=(--add-flags "--use-gl=angle --use-angle=vulkan --enable-features=VulkanFromANGLE,DefaultANGLEVulkan")
          gappsWrapperArgs+=(--set VK_ICD_FILENAMES "$out/opt/ticktick/vk_swiftshader_icd.json")
        '';
      }))
      evince # (gnome) pdf reader
      blockbench # low-poly 3D modeling and animation
      freecad # CAD
      openscad # parametric CAD
      (inkscape-with-extensions.override {
        inkscapeExtensions = [ inkscape-extensions.inkstitch ];
      })
      orca-slicer
      # Native Plasticity: wrapped in gamescope to gate 1000Hz mouse events to frame rate —
      # Plasticity's snapping (possiblyModifyPickedPoint) runs per-event and floods the NURBS
      # kernel at 1000Hz, causing "Dropping job because of latency" on every mouse move.
      # Gamescope dispatches input to the child at its own frame clock (~240Hz), keeping jobs
      # within budget. ANGLE/Vulkan flags fix RDNA 4 EGL passthrough.
      (pkgs.symlinkJoin {
        name = "plasticity";
        paths = [
          (pkgs.plasticity.overrideAttrs (_: {
            preFixup = ''
              gappsWrapperArgs+=(--add-flags "--use-gl=angle --use-angle=vulkan --enable-features=VulkanFromANGLE,DefaultANGLEVulkan --enable-gpu-rasterization")
              gappsWrapperArgs+=(--set VK_ICD_FILENAMES /run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json)
            '';
          }))
        ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          makeWrapper ${pkgs.gamescope}/bin/gamescope $out/bin/plasticity \
            --add-flags "-w 1920 -h 1080 -W 2560 -H 1440 --nested-refresh 240 --nested-unfocused-refresh 240 -- $out/bin/Plasticity"
        '';
      })
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
      gamescope # Gaming compositor (also used to gate Plasticity input to frame rate)

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
      duf # disk usage/free utility
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
      nixfmt # nix formatter
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
