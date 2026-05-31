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
    # hyprnotify is used for notifications (configured in hyprland/config.nix)
    ./wezterm.nix # terminal
    ./discord/discord.nix # discord with gruvbox
    ./git.nix # version control
    ./lazygit.nix
    ./claude.nix # AI coding assistant
    ./spicetify.nix # spotify client
    ./mpv.nix # media player
    ./plasticity.nix # plasticity CAD (AppImage)
    ./packages.nix # additional packages
    ./browser.nix # zen browser
    ./gtk.nix # gtk theme
    ./xdg-mimes.nix # file associations
    ./clouddrives.nix # cloud drive sync services (OneDrive)

    # Ready to enable when needed:
    # ./ags - Simple bar widget (migrated from chezmoi)

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
  ];
}
