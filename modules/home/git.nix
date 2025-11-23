{ pkgs, ... }:
{
  programs = {
    git = {
      enable = true;
      settings = {
        user = {
          name = "rupel";
          email = "23055682+rupel190@users.noreply.github.com";
        };

        init.defaultBranch = "main";
        core.editor = "nvim";

        aliases = {
          st = "status";
          b = "branch";
          logo = "log --oneline --name-only --graph";
        };
      };
      # Enable LFS (Large File Storage)
      lfs.enable = true;

    };

    # Delta - better diffs with syntax highlighting!
    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        line-numbers = true;
        side-by-side = true;
        navigate = true;
      };
    };
  };
  # GitHub CLI
  home.packages = with pkgs; [
    gh
    git-lfs
  ];
}
