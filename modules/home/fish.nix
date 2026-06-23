{
  config,
  pkgs,
  lib,
  ...
}:
let
  getProgramName = pkg: pkg.meta.mainProgram or pkg.pname or (lib.getName pkg);
  allowedCmds = lib.concatStringsSep "\n" (map getProgramName config.home.packages);
in
{
  xdg.configFile."tldr-allowlist".text = allowedCmds;

  # TODO: replace theming
  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      # WezTerm shell integration — emits OSC 133 semantic zone marks so that
      # ScrollToPrompt (shift+up/down) and copy-last-output (ctrl+shift+c) work reliably
      if set -q WEZTERM_PANE
        function __wezterm_prompt_start --on-event fish_prompt
          printf "\e]133;A\e\\"
        end
        function __wezterm_command_start --on-event fish_preexec
          printf "\e]133;C\e\\"
        end
        function __wezterm_command_end --on-event fish_postexec
          printf "\e]133;D;%s\e\\" $status
        end
      end

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
        tldr-installed
        weather
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

      # gtrash completions
      gtrash completion fish | source
    '';

    shellAbbrs = {
      rm = "gtrash put";

      sc = "sudo systemctl";
      scu = "systemctl --user";
      scus = "systemctl --user status";
      scur = "systemctl --user restart";

      se = "sudoedit";
      vault = "cd /home/rupel/.local/share/Cryptomator/mnt/Vault";
      mac-trichoderma = "e0:d5:5e:4f:29:42";
      cl = "claude";
      pm = "pulsemixer";
    };

    functions = {
      fish_prompt = {
        description = "Informative prompt";
        body = ''
          set -l last_pipestatus $pipestatus
          set -lx __fish_last_status $status

          if functions -q fish_is_root_user; and fish_is_root_user
            printf '%s@%s %s%s%s# ' $USER (prompt_hostname) (set -q fish_color_cwd_root
                                                               and set_color $fish_color_cwd_root
                                                               or set_color $fish_color_cwd) \
                (prompt_pwd) (set_color normal)
          else
            set -l status_color (set_color $fish_color_status)
            set -l statusb_color (set_color --bold $fish_color_status)
            set -l pipestatus_string (__fish_print_pipestatus "[" "]" "|" "$status_color" "$statusb_color" $last_pipestatus)

            printf '[%s] %s%s@%s %s%s %s%s%s \n> ' (date "+%H:%M:%S") (set_color brblue) \
                $USER (prompt_hostname) (set_color $fish_color_cwd) $PWD $pipestatus_string \
                (set_color normal)
          end
          if set -q WEZTERM_PANE
            printf "\e]133;B\e\\"
          end
        '';
      };

      # Override default fish_title which appends cwd to the title
      fish_title = ''
        set -l cmd (status current-command)
        test "$cmd" = fish; and set cmd
        set -q SSH_TTY; and set -l ssh "["(prompt_hostname | string sub -l 10)"]"
        echo -- $ssh $cmd
      '';

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

      tldr-ignore = {
        description = "Add a command to ~/.config/tldr-ignore";
        body = ''
          if test (count $argv) -eq 0
            echo "Usage: tldr-ignore <command>"
            return 1
          end
          echo $argv[1] >> ~/.config/tldr-ignore
          echo "Ignored '$argv[1]'"
        '';
      };

      tldr-tip = {
        description = "Show a random tldr command tip from all pages, skipping ~/.config/tldr-ignore";
        body = ''
          set -l ignore_file ~/.config/tldr-ignore
          touch $ignore_file
          set -l cmd (tldr --list 2>/dev/null | grep -vFxf $ignore_file | shuf -n 1 | string trim)
          test -z "$cmd"; and return
          set -l desc (tldr $cmd 2>/dev/null | string match -rv '^\s*$' | head -2 | tail -1 | string replace -r '\.\s+.+' '.' | string trim)
          echo "✦ $cmd — $desc"
        '';
      };

      tldr-installed = {
        description = "Show a random tldr tip for an installed package, skipping ~/.config/tldr-ignore";
        body = ''
          set -l ignore_file ~/.config/tldr-ignore
          touch $ignore_file
          set -l cmd (tldr --list 2>/dev/null | grep -xFf ~/.config/tldr-allowlist | grep -vFxf $ignore_file | shuf -n 1 | string trim)
          test -z "$cmd"; and return
          set -l desc (tldr $cmd 2>/dev/null | string match -rv '^\s*$' | head -2 | tail -1 | string replace -r '\.\s+.+' '.' | string trim)
          echo "✦ $cmd — $desc"
        '';
      };

      # Custom weather panel built from wttr.in JSON (?format=j1) with jq.
      # We render our own layout: current temp + feels-like, then the rest of
      # today (morning/noon/evening/night) with rain %, day/night icons — no
      # wind or visibility clutter. The hourly array is in 3-hour steps, so
      # indices 3/4/6/7 = 09:00 / 12:00 / 18:00 / 21:00. ic() buckets WWO
      # weather codes (113 clear, 116 partly, 200/386 thunder, …) into emoji,
      # kept last in each row so their double-width can't break alignment.
      # Cached ~15 min so it never delays an interactive shell and keeps the
      # last good copy offline. Swap "Wien" to retarget; run `weather` to refresh.
      weather = {
        description = "Cached weather panel (current + rest of today, rain %) from wttr.in JSON";
        body = ''
          set -l cache $HOME/.cache/wttr-forecast
          if not test -f $cache; or test (find $cache -mmin +15 2>/dev/null | count) -gt 0
            if curl -fsS --max-time 4 'https://wttr.in/Wien?format=j1' 2>/dev/null | jq -r '
                def ic($code; $night):
                  ($code|tonumber) as $c
                  | if   $c == 113 then (if $night then "🌙" else "☀️" end)
                    elif $c == 116 then "⛅"
                    elif ($c == 119 or $c == 122) then "☁️"
                    elif ($c == 143 or $c == 248 or $c == 260) then "🌫️"
                    elif ($c >= 386 or $c == 200) then "⛈️"
                    elif (($c >= 317 and $c <= 377) or $c == 227 or $c == 230) then "🌨️"
                    elif ($c >= 293) then "🌧️"
                    else "🌦️" end;
                def rpad($n): . as $s | $s + (($n - ($s|length)) as $k | if $k>0 then " "*$k else "" end);
                def lpad($n): . as $s | (($n - ($s|length)) as $k | if $k>0 then " "*$k else "" end) + $s;
                .current_condition[0] as $cur
                | .weather[0].hourly as $h
                | def row($l; $t; $mid; $code; $night):
                    "  " + ($l|rpad(8)) + ($t|tostring|lpad(2)) + " °C   " + ($mid|rpad(12)) + ic($code; $night);
                  "Wien · rest of today",
                  row("now";     $cur.temp_C;  ("feels " + $cur.FeelsLikeC + " °C");            $cur.weatherCode;  false),
                  row("morning"; $h[3].tempC;  ("rain " + ($h[3].chanceofrain|lpad(3)) + " %"); $h[3].weatherCode; false),
                  row("noon";    $h[4].tempC;  ("rain " + ($h[4].chanceofrain|lpad(3)) + " %"); $h[4].weatherCode; false),
                  row("evening"; $h[6].tempC;  ("rain " + ($h[6].chanceofrain|lpad(3)) + " %"); $h[6].weatherCode; false),
                  row("night";   $h[7].tempC;  ("rain " + ($h[7].chanceofrain|lpad(3)) + " %"); $h[7].weatherCode; true)
              ' > $cache.tmp 2>/dev/null; and test -s $cache.tmp
              mv $cache.tmp $cache
            else
              rm -f $cache.tmp
            end
          end
          test -f $cache; and cat $cache; or echo "weather unavailable"
        '';
      };

      # Godot launcher shortcut
      godot = "command godot --rendering-driver opengl3 $argv";

      # Flatpak apps
      bambu-studio = "flatpak run --env=VK_ICD_FILENAMES=/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json com.bambulab.BambuStudio $argv";

      # Terminal image display
      imgcat = "wezterm imgcat $argv";

      # One-shot song recognition from active audio output — prints and copies result to clipboard
      shazam = {
        description = "Identify currently playing song from active audio output (one-shot)";
        body = ''
          set -l sink (pactl get-default-sink)
          set -l result (songrec recognize --audio-device "$sink.monitor" --json 2>/dev/null | jq -r 'if .track then "\(.track.subtitle) – \(.track.title)" else empty end')
          if test -n "$result"
            echo $result
            echo $result | wl-copy
          else
            echo "No match found" >&2
            return 1
          end
        '';
      };

      # Continuous song logging — deduplicates adjacent matches, appends to TSV history
      shazam-auto = {
        description = "Continuously log recognized songs to ~/.local/share/shazam-history.tsv";
        body = ''
          set -l logfile $HOME/.local/share/shazam-history.tsv
          set -l sink (pactl get-default-sink)
          echo "Listening on $sink.monitor — logging to $logfile (Ctrl-C to stop)"
          set -l prev ""
          songrec listen --audio-device "$sink.monitor" --json 2>/dev/null \
            | jq --unbuffered -r 'if .track then "\(.track.subtitle)\t\(.track.title)" else empty end' \
            | while read -l entry
              if test "$entry" != "$prev"
                set prev $entry
                set -l line (date "+%Y-%m-%d %H:%M")(printf '\t')$entry
                echo $line
                echo $line >> $logfile
              end
            end
        '';
      };
    };

  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  # Keep the tldr page cache fully populated OFF the interactive path. `tldr-installed`
  # picks a random page at shell startup; the client fetches any uncached page over the
  # network (~1.5s), so random picks were stalling the prompt. A periodic full refresh
  # makes every pick a local cache hit.
  systemd.user.services.tldr-update = {
    Unit.Description = "Refresh the tldr page cache";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.tldr}/bin/tldr --update";
    };
  };
  systemd.user.timers.tldr-update = {
    Unit.Description = "Refresh the tldr page cache weekly";
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
