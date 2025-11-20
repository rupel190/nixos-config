{
  config,
  pkgs,
  lib,
  ...
}:
{

  # TODO: replace theming
  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      fish_vi_key_bindings

      # Fish shell colors (Catppuccin Macchiato)
      set -g fish_color_normal cad3f5
      set -g fish_color_command 8aadf4
      set -g fish_color_param f0c6c6
      set -g fish_color_keyword ed8796
      set -g fish_color_quote a6da95
      set -g fish_color_redirection f5bde6
      set -g fish_color_end f5a97f
      set -g fish_color_comment 8087a2
      set -g fish_color_error ed8796
      set -g fish_color_gray 6e738d
      set -g fish_color_selection --background=363a4f
      set -g fish_color_search_match --background=363a4f
      set -g fish_color_option a6da95
      set -g fish_color_operator f5bde6
      set -g fish_color_escape ee99a0
      set -g fish_color_autosuggestion 6e738d
      set -g fish_color_cancel ed8796
      set -g fish_color_cwd eed49f
      set -g fish_color_user 8bd5ca
      set -g fish_color_host 8aadf4
      set -g fish_color_host_remote a6da95
      set -g fish_color_status ed8796

      # Fish pager colors
      set -g fish_pager_color_progress 6e738d
      set -g fish_pager_color_prefix f5bde6
      set -g fish_pager_color_completion cad3f5
      set -g fish_pager_color_description 6e738d
    '';

    loginShellInit = ''
      if status is-interactive
        fastfetch
      end
    '';

    # Runs for all fish shells (interactive + login + scripts)
    shellInit = ''
      set -a PATH /home/rupel/.local/bin
      # Envvars
      set -g fish_greeting
      set -gx EDITOR nvim
      set -gx TERMINAL wezterm

      # Catppuccin Macchiato color palette
      set -l rosewater 'f4dbd6'
      set -l flamingo 'f0c6c6'
      set -l pink 'f5bde6'
      set -l mauve 'c6a0f6'
      set -l red 'ed8796'
      set -l maroon 'ee99a0'
      set -l peach 'f5a97f'
      set -l yellow 'eed49f'
      set -l green 'a6da95'
      set -l teal '8bd5ca'
      set -l sky '91d7e3'
      set -l sapphire '7dc4e4'
      set -l blue '8aadf4'
      set -l lavender 'b7bdf8'

      set -l text 'cad3f5'
      set -l subtext1 'b8c0e0'
      set -l subtext0 'a5adcb'
      set -l overlay2 '939ab7'
      set -l overlay1 '8087a2'
      set -l overlay0 '6e738d'
      set -l surface2 '5b6078'
      set -l surface1 '494d64'
      set -l surface0 '363a4f'

      set -l base '24273a'
      set -l mantle '1e2030'
      set -l crust '181926'

      # FZF colors using Catppuccin palette
      set -gx FZF_DEFAULT_OPTS "\
      --color=bg+:#$surface0,bg:#$base,spinner:#$rosewater,hl:#$red \
      --color=fg:#$text,header:#$red,info:#$mauve,pointer:#$rosewater \
      --color=marker:#$lavender,fg+:#$text,prompt:#$mauve,hl+:#$red \
      --color=selected-bg:#$surface1 \
      --color=border:#$surface0,label:#$text"

      # Disable FZF's alt-c command (we use zoxide)
      set -e FZF_ALT_C_COMMAND
    '';

    shellAbbrs = {
      sc = "sudo systemctl";
      scu = "systemctl --user";
      scus = "systemctl --user status";
      scur = "systemctl --user restart";

      cm = "chezmoi cd";
      cma = "chezmoi apply";
      cme = "chezmoi edit ~/.config/";
      dot = "nvim /home/rupel/.local/share/chezmoi/dot_config/";

      se = "sudoedit";
      vault = "cd /home/rupel/.local/share/Cryptomator/mnt/Vault";
      hyprconf = "nvim /home/rupel/.config/hypr";
    };

    functions = {
      # ls using eza
      ls = {
        wraps = "eza";
        body = "eza --icons=always $argv";
      };

      # tree using eza
      tree = {
        wraps = "eza";
        body = "eza --tree --icons=always $argv";
      };

      catppuccinify-video = {
        description = "Catppuccinify a video with hald CLUT (ffmpeg)";
        body = ''
          argparse 'f/flavor=' 'l/level=' 'o/output=' h/help -- $argv
          or return 1

          if set -q _flag_help
            echo "Usage: catppuccinify-video [options] <input.mp4>"
            echo "Options:"
            echo "  -f, --flavor FLAVOR   Catppuccin flavor (default: macchiato)"
            echo "  -l, --level LEVEL     Hald CLUT level (default: 8)"
            echo "  -o, --output OUTPUT   Output filename"
            echo "  -h, --help           Show this help"
            return 0
          end

          if test (count $argv) -eq 0
            echo "Error: input file required" >&2
            return 1
          end

          set -l in $argv[1]
          set -l flavor (string lower -- (string length -q -- "$_flag_flavor"; and echo $_flag_flavor; or echo macchiato))
          set -l level (string length -q -- "$_flag_level"; and echo $_flag_level; or echo 8)
          set -l out (string length -q -- "$_flag_output"; and echo $_flag_output; or echo (string replace -r '\.[^.]*$' "" (basename "$in"))"-ctp-$flavor.mp4")

          set -l hald "/tmp/hald$level-$flavor.png"

          magick hald:$level hald$level.png
          catppuccinifier --flavor $flavor --hald $level hald$level.png -d /tmp/
          ffmpeg -hide_banner -y -i "$in" -i "$hald" \
            -filter_complex "[0:v][1:v]haldclut" -c:a copy "$out"
        '';
      };

      # Godot launcher shortcut
      godot = "command godot --rendering-driver opengl3 $argv";

      # Terminal image display
      imgcat = "wezterm imgcat $argv";
    };

  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
}
