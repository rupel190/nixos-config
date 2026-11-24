{ pkgs, lib, ... }:
let
  # commit-msg hook: drops the lines Claude Code appends to a commit message. Human co-authors stay.
  stripAiTrailers = pkgs.writeShellApplication {
    name = "strip-ai-trailers";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      gnused
    ];
    bashOptions = [
      "errexit"
      "nounset"
    ];
    text = ''
      msg="$1"
      lines='^(co-authored-by:.*<noreply@anthropic\.com>|claude-session:[[:space:]]*https://claude\.ai/.*)[[:space:]]*$'
      # LC_ALL=C and -a: otherwise grep drops text from a message that is not valid UTF-8
      LC_ALL=C grep -aqiE "$lines" "$msg" || exit 0
      tmp="$(mktemp)"
      LC_ALL=C grep -aviE "$lines" "$msg" > "$tmp" || true
      # the blank line that stood above the trailers goes with them
      LC_ALL=C sed -e :a -e '/^[[:space:]]*$/{$d;N;ba' -e '}' "$tmp" > "$msg"
      rm -f "$tmp"
    '';
  };
in
{
  # A path that survives rebuilds. Git before 2.54 ignores the hook setting below, so repos whose
  # devshell ships an older git need it as .git/hooks/commit-msg:
  #   ln -s ~/.config/git/strip-ai-trailers .git/hooks/commit-msg
  xdg.configFile."git/strip-ai-trailers".source = lib.getExe stripAiTrailers;

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

        # Runs alongside a repo's own hooks; core.hooksPath would replace them (git-lfs, husky).
        # Off for one repo: git config hook.strip-ai-trailers.enabled false
        hook.strip-ai-trailers = {
          command = lib.getExe stripAiTrailers;
          event = "commit-msg";
        };

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
