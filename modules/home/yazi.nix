{ inputs, pkgs, ... }:
{
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;

    keymap = {
      mgr.prepend_keymap = [
        {
          on = [ "<C-n>" ];
          run = ''shell 'ripdrag "$@" -x 2>/dev/null &' --confirm'';
          desc = "Drag & Drop with ripdrag";
        }
        # Swap tab/space
        {
          on = [ "<Tab>" ];
          run = [
            "toggle"
            "arrow next"
          ];
          desc = "Toggle selection and move to next";
        }
        {
          on = [ "<Space>" ];
          run = "spot";
          desc = "Quick preview (spot) file";
        }
        # zoxide and fzf
        {
          on = [ "z" ];
          run = "plugin zoxide";
          desc = "Jump to directory with zoxide";
        }
        {
          on = [ "Z" ];
          run = ''shell 'ya pub dds-cd --str "$(fd -td | fzf)"' --confirm'';
          desc = "Jump to directory with fzf";
        }
      ];

      # In spot mode, use Space to close (not Tab)
      spot.prepend_keymap = [
        {
          on = [ "<Space>" ];
          run = "close";
          desc = "Close the spot";
        }
      ];
    };

    # TODO: Check which to keep
    settings = {
      mgr = {
        linemode = "size";
        show_hidden = true;
        show_symlink = true;
        sort_by = "natural";
        sort_dir_first = true;
        sort_reverse = false;
        sort_sensitive = false;
      };

      preview = {
        # Enable image preview
        image_filter = "lanczos3";
        image_quality = 90;
        max_width = 600;
        max_height = 900;
      };

      tasks = {
        # Preview for large image files
        image_alloc = 1073741824; # 1GB for large images
      };
    };
  };

  # Install Catppuccin theme
  xdg.configFile."yazi/flavors/catppuccin-macchiato.yazi" = {
    source = pkgs.fetchFromGitHub {
      owner = "catppuccin";
      repo = "yazi";
      rev = "main";
      sha256 = "sha256-zkL46h1+U9ThD4xXkv1uuddrlQviEQD3wNZFRgv7M8Y=";
    };
  };

  # Use the theme
  xdg.configFile."yazi/theme.toml".text = ''
    [flavor]
    use = "catppuccin-macchiato"
  '';
}
