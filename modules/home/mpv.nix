{ pkgs, ... }:
{
  programs.mpv = {
    enable = true;

    config = {
      # Catppuccin Macchiato colors
      background-color = "#24273a"; # Base
      osd-back-color = "#181926"; # Crust
      osd-border-color = "#181926"; # Crust
      osd-color = "#cad3f5"; # Text
      osd-shadow-color = "#24273a"; # Base
    };

    # uosc = modern UI; cut = c marks start/end of a lossless clip, a cycles copy/encode
    scripts = with pkgs.mpvScripts; [
      uosc
      cut
    ];

    scriptOpts = {
      # Stats script (colors in #BBGGRR format) - press i for status overlay
      stats = {
        border_color = "30201e";
        font_color = "f5d3ca";
        plot_bg_border_color = "c6c6f0";
        plot_bg_color = "30201e";
        plot_color = "c6c6f0";
      };

      # UOSC script colors
      uosc = {
        color = "foreground=f0c6c6,foreground_text=363a4f,background=24273a,background_text=cad3f5,curtain=1e2030,success=a6da95,error=ed8796";
      };
    };
  };

  # mpv-cut has no output-dir option; wrap its actions to write into ~/Videos/mpv-cut
  xdg.configFile."mpv-cut/config.lua".text = ''
    local outdir = mp.command_native({ "expand-path", "~/Videos/mpv-cut" })
    for name, action in pairs(ACTIONS) do
      if name ~= "LIST" then
        ACTIONS[name] = function(d)
          mp.command_native({ name = "subprocess", args = { "mkdir", "-p", outdir }, playback_only = false })
          d.indir = outdir
          action(d)
        end
      end
    end

    -- keep i for stats; bookmarks and channels unused
    KEY_BOOKMARK_ADD = nil
    KEY_CHANNEL_INC = nil
    KEY_CHANNEL_DEC = nil
  '';
}
