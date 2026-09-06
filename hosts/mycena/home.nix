# home-manager for mycena. Deliberately self-contained: it does NOT import
# ../../modules/home, which is the full Hyprland/AGS/Spotify workstation. Pull
# individual modules from there later only if one earns its place on a wall panel.
#
# There is no compositor config here on purpose. Phosh owns the session
# (see ./wall.nix) and brings its own shell, top bar, app grid and OSK, so this
# file is only user identity plus the apps that should appear in that grid.
{
  pkgs,
  username,
  ...
}:
{
  home.username = username;
  home.homeDirectory = "/home/${username}";

  programs.home-manager.enable = true;
  programs.fish.enable = true;

  # Identity matches modules/home/git.nix; the rest of that module (delta,
  # aliases, LFS) is workstation polish this host does not need.
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "rupel";
        email = "23055682+rupel190@users.noreply.github.com";
      };
      init.defaultBranch = "main";
    };
  };

  # These land in /etc/profiles/per-user/${username}/share/applications, which
  # is on the session's XDG_DATA_DIRS, so each one shows up as a tappable icon
  # in Phosh's app grid.
  home.packages = with pkgs; [
    firefox
    brightnessctl
  ];

  # Wayland-native terminal; far lighter than the wezterm used on the
  # workstations, and its large default font survives a 2x scaled panel.
  programs.foot = {
    enable = true;
    settings.main.font = "monospace:size=12";
  };

  # Same reasoning as the system stateVersion: a frozen record of when this
  # profile was created, not a version to keep current.
  home.stateVersion = "26.05";
}
