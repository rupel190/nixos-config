let
  workspaces = {
    browser = 1;
    code = 2;
    communication = 3;
    media = 4;
  };
in
{
  wayland.windowManager.hyprland.settings = {
    cursor = {
      default_monitor = "DP-2";
    };

    gestures {
      gesture = "3, horizontal, workspace";
    };

    monitor = [
      "DP-1, 3840x2160@120.00000, -2560x0, 1.5"
      "DP-2, 2560x1440@239.972000, 0x0, 1"
      "HDMI-A-2, preferred, 2560x0, 1, transform, 3" # Vertical
      "HDMI-A-1, 3840x2160@60.00000, -3840x0, 3, vrr, 0" # AVR

      {{- if eq .chezmoi.hostname "cordyceps" }}
# monitor = eDP-1, 2880x1920@120.00000
      {{- end }}


    ];
    workspace = [
      "${toString workspaces.browser}, monitor:DP-2"
      "${toString workspaces.code}, monitor:DP-1"
      "${toString workspaces.communication}, monitor:HDMI-A-1"
    ];

    windowrulev2 = [
      "workspace ${toString workspaces.browser} silent, class:^(firefox)$"
      "workspace ${toString workspaces.code} silent, class:^(code)$"
      "workspace 4 silent, class:^(app.zen_browser.zen)$"
      "workspace 4, class:^(zen)$"
      "workspace 7 silent, class:^(ticktick|Proton Mail|Slack|class.org.keepassxc.KeePassXC)$"
      "workspace 8 silent, class:^(discord|Signal)$"
      "workspace 9 silent, class:^(Spotify)$"
    ];

    bind = [
      "$mainMod, 1, workspace, ${toString workspaces.browser}"
      "$mainMod, 2, workspace, ${toString workspaces.code}"
    ];
  };
}
