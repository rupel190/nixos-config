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

    ./browser.nix # firefox based browser
    ./gnome.nix # gnome apps
    ./gtk.nix # gtk theme
    ./hyprland # window manager
    ./nvim.nix # neovim editor
    ./obsidian.nix
    ./packages.nix # other packages
    ./scripts/scripts.nix # personal scripts
    ./xdg-mimes.nix # xdg config
  ];
}
