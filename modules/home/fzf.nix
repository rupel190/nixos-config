{ pkgs, ... }:
{
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    fileWidgetCommand = "fd --type f --hidden --follow --exclude .git"; # For CTRL-T

    ## Theme
    # defaultOptions = [
    #   "--color=fg:-1,fg+:#FBF1C7,bg:-1,bg+:#282828"
    #   "--color=hl:#98971A,hl+:#B8BB26,info:#928374,marker:#D65D0E"
    #   "--color=prompt:#CC241D,spinner:#689D6A,pointer:#D65D0E,header:#458588"
    #   "--color=border:#665C54,label:#aeaeae,query:#FBF1C7"
    #   "--border='double' --border-label='' --preview-window='border-sharp' --prompt='> '"
    #   "--marker='>' --pointer='>' --separator='─' --scrollbar='│'"
    #   "--info='right'"
    # ];
  };
}
