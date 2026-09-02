{
  inputs,
  lib,
  username,
  host,
  ...
}:
{
  imports = [
    ./fish.nix # shell
    ./fzf.nix # fuzzy finder
    ./yazi.nix # terminal file manager
    ./cava/cava.nix # audio visualizer
    ./surge.nix # download manager
    ./darya.nix # disk usage visualizer
    ./btop # resouces monitor
    ./bat.nix # better cat command
    ./fastfetch.nix # fetch tool
    # swaync notification center (service enabled in packages.nix)
    ./wezterm.nix # terminal
    ./discord/discord.nix # vesktop (discord web + vencord)
    ./git.nix # version control
    ./lazygit.nix
    ./claude.nix # AI coding assistant
    ./opencode.nix # AI coding assistant (model-agnostic alternative)
    ./spicetify.nix # spotify client
    ./qbz.nix # qobuz hi-fi client (AppImage)
    ./mpv.nix # media player
    ./tera.nix # terminal radio player
    ./pulsemixer.nix # audio mixer (patched selection highlight)
    ./plasticity.nix # plasticity CAD (AppImage)
    ./packages.nix # additional packages
    ./browser.nix # zen browser
    ./vicinae.nix # launcher + browser tab integration (native messaging host)
    ./gtk.nix # gtk theme
    ./xdg-mimes.nix # file associations
    ./clouddrives.nix # cloud drive sync services (OneDrive)

    ./ags # status bar (AGS 3 / Astal, GTK4) — runs as a systemd user unit

    # Unmanaged app configs (deployed as-is)
    ./dotfiles

    # Window manager - fully migrated!
    ./hyprland

    # Laptop-specific (import in hosts/cordyceps home config):
    # ./laptop-only.nix - poweralertd, brightness tools

    # Skipped (not using):
    # - nvim.nix (deleted - using Lazyvim config)
    # - obsidian.nix (using standalone?)
    # - viewnior.nix (image viewer)
    # - waypaper.nix (not using wallpaper management)
    # - scripts/ (removed - using AGS instead)
  ] ++ lib.optionals (host == "amanita") [
    ./pi-backup.nix # weekly pull of RPi backups to silo + OneDrive (amanita only)
  ] ++ lib.optionals (host == "cordyceps") [
    ./laptop-only.nix # brightness, battery, touchpad settings
  ];
}
