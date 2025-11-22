{
  inputs,
  username,
  host,
  ...
}:
{
  imports = [
    ./fish.nix # shell
    ./fzf.nix # fuzzy finder
    ./yazi.nix # terminal file manager
    ./cava.nix # audio visualizer
    ./btop.nix # resouces monitor
    ./bat.nix # better cat command
    ./fastfetch.nix # fetch tool
    ./swaync/swaync.nix # notification daemon
    ./wezterm.nix # terminal
    ./discord/discord.nix # discord with gruvbox
    ./git.nix # version control
    ./lazygit.nix
    ./spicetify.nix # spotify client
    ./mpv.nix # media player
    ./packages.nix # additional packages
    ./browser.nix # zen browser
    ./gtk.nix # gtk theme
    ./xdg-mimes.nix # file associations

    # Ready to enable when needed:
    # ./ags - Simple bar widget (migrated from chezmoi)

    # TODO: FINAL STEP
    # ./hyprland - Window manager (most important, save for last)

    # Skipped (not using):
    # - obsidian.nix (using standalone?)
    # - xdg-mimes.nix (using system defaults?)
    # - viewnior.nix (image viewer)
    # - waypaper.nix (not using wallpaper management)
    # - scripts/ (removed - using AGS instead)
  ];
}
