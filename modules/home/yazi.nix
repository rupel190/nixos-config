{ inputs, pkgs, ... }:
{
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    shellWrapperName = "y";

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

    settings = {
      mgr = {
        linemode = "size";
        show_hidden = false;
        show_symlink = true;
        sort_by = "mtime";
        sort_dir_first = true;
        sort_reverse = true;
        sort_sensitive = false;
      };

      preview = {
        image_filter = "lanczos3";
        image_quality = 90;
        max_width = 600;
        max_height = 900;
      };

      tasks = {
        image_alloc = 1073741824;
      };

      # Define openers - call apps directly (bypasses broken xdg-open portal)
      opener = {
        image = [
          {
            run = ''imv "$@"'';
            orphan = true;
            desc = "Open in imv";
          }
        ];
        video = [
          {
            run = ''mpv "$@"'';
            orphan = true;
            desc = "Play in mpv";
          }
        ];
        audio = [
          {
            run = ''mpv "$@"'';
            orphan = true;
            desc = "Play in mpv";
          }
        ];
        pdf = [
          {
            run = ''evince "$@"'';
            orphan = true;
            desc = "Open in Evince";
          }
        ];
        browser = [
          {
            run = ''zen "$@"'';
            orphan = true;
            desc = "Open in Zen";
          }
        ];
        edit = [
          {
            run = ''$EDITOR "$@"'';
            block = true;
            desc = "Edit in $EDITOR";
          }
        ];
        bambu-studio = [
          {
            run = ''flatpak run --env=VK_ICD_FILENAMES=/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json com.bambulab.BambuStudio "$@"'';
            orphan = true;
            desc = "Open in Bambu Studio";
          }
        ];
        plasticity = [
          {
            run = ''plasticity "$@"'';
            orphan = true;
            desc = "Open in Plasticity";
          }
        ];
      };

      # Map MIME types to openers
      open = {
        prepend_rules = [
          # url-glob rules take priority — catches .step (detected as text/plain) and
          # .3mf (ZIP-based, yazi would otherwise try to browse it as an archive).
          # NOTE: yazi renamed the glob key `name` -> `url`; using `name` now errors with
          # "at least one of `url` or `mime` must be specified".
          {
            url = "*.3mf";
            use = "bambu-studio";
          }
          {
            url = "*.step";
            use = "plasticity";
          }
          {
            url = "*.stp";
            use = "plasticity";
          }
          {
            mime = "image/*";
            use = "image";
          }
          {
            mime = "video/*";
            use = "video";
          }
          {
            mime = "audio/*";
            use = "audio";
          }
          {
            mime = "application/pdf";
            use = "pdf";
          }
          {
            mime = "text/html";
            use = "browser";
          }
          {
            mime = "text/*";
            use = "edit";
          }
        ];
      };
    };
  };

  # Install Catppuccin theme
  xdg.configFile."yazi/flavors/catppuccin-macchiato.yazi" = {
    source = pkgs.fetchFromGitHub {
      owner = "catppuccin";
      repo = "yazi";
      rev = "main";
      sha256 = "sha256-Og33IGS9pTim6LEH33CO102wpGnPomiperFbqfgrJjw=";
    };
  };

  # Use the theme
  xdg.configFile."yazi/theme.toml".text = ''
    [flavor]
    use = "catppuccin-macchiato"
  '';
}
