# home-manager for mycena. Deliberately minimal and self-contained: it does NOT
# import ../../modules/home, which is the full Hyprland/AGS/Spotify/Plasticity
# workstation. Pull individual modules from there later if a specific one earns
# its place on a wall panel.
{ username, ... }:
{
  home.username = username;
  home.homeDirectory = "/home/${username}";

  programs.home-manager.enable = true;

  # Matches the login shell set in default.nix.
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

  # Same reasoning as the system stateVersion: a frozen record of when this
  # profile was created, not a version to keep current.
  home.stateVersion = "26.05";
}
