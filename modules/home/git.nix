{ pkgs, ... }:
{
  programs.git = {
    enable = true;

    userName = "rupel";
    userEmail = "23055682+rupel190@users.noreply.github.com";

    extraConfig = {
      init.defaultBranch = "main";
      core.editor = "nvim";
    };

    aliases = {
      st = "status";
      b = "branch";
      logo = "log --oneline --name-only --graph";
    };

    # Delta - better diffs with syntax highlighting!
    delta = {
      enable = true;
      options = {
        line-numbers = true;
        side-by-side = true;
        navigate = true;
      };
    };

    # Enable LFS (Large File Storage)
    lfs.enable = true;
  };

  # GitHub CLI
  home.packages = with pkgs; [
    gh
    git-lfs
  ];
}
