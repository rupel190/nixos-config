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

        alias = {
          st = "status";
          b = "branch";
          logo = "log --oneline --name-only --graph";
          dt = "difftool --no-symlinks --dir-diff"; # every changed file in one kitten diff
        };

        # kitten diff for `git difftool` (kitty only); delta stays the pager
        diff.tool = "kitty";
        difftool = {
          prompt = false;
          trustExitCode = true;
          kitty.cmd = "kitten diff $LOCAL $REMOTE";
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
        wrap-max-lines = "unlimited"; # wrap long lines fully instead of cutting them after two
      };
    };
  };
  # GitHub CLI
  home.packages = with pkgs; [
    gh
    git-lfs
  ];
}
