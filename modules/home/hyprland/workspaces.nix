{ host, ... }:
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
      no_hardware_cursors = true;
    };

    # Desktop monitor configuration (amanita)
    # Laptop monitor config is in hosts/cordyceps/default.nix
    monitor = [
      "DP-2, 2560x1440@239.972000, 0x0, 1"
      "DP-1, 3840x2160@120.00000, -2560x0, 1.5"
      "HDMI-A-2, preferred, 2560x0, 1, transform, 3"
      # "DP-1, 3840x2160@120.00000, -3840x0, 1"
      # "HDMI-A-1, 3840x2160@60.00000, -3840x0, 1" # AVR place left of 4k
      # "HDMI-A-1, 3840x2160@60.00000, -2560, 1" # AVR placed left of 2560p

      # "HDMI-A-1, disabled"
      # "DP-1, disabled"
    ];
    workspace =
      if host == "amanita" then
        [
          # DP-1 (Left 4K monitor)
          "1, monitor:DP-1, persistent:true, layoutopt:orientation:top"
          "2, monitor:DP-1, persistent:true"
          "3, monitor:DP-1, persistent:true"

          # DP-2 (Center main monitor)
          "4, monitor:DP-2, persistent:true, default:true, name:main"
          "5, monitor:DP-2, persistent:true"
          "6, monitor:DP-2, persistent:true"

          # HDMI-A-2 (Right vertical monitor)
          "7, monitor:HDMI-A-2, persistent:true, default:true, layoutopt:orientation:top"
          "8, monitor:HDMI-A-2, persistent:true, layoutopt:orientation:top"
          "9, monitor:HDMI-A-2, persistent:true"
        ]
      else
        [
          # Default workspace assignments
          "${toString workspaces.browser}, monitor:DP-2"
          "${toString workspaces.code}, monitor:DP-1"
          "${toString workspaces.communication}, monitor:HDMI-A-1"
        ];

    # TODO: fix, maybe deprecated on new hyprland conf?
    # windowrulev2 = [
    #   "workspace ${toString workspaces.browser} silent, class:^(firefox)$"
    #   "workspace ${toString workspaces.code} silent, class:^(code)$"
    #   "workspace 4 silent, class:^(app.zen_browser.zen)$"
    #   "workspace 4, class:^(zen)$"
    #   "workspace 7 silent, class:^(ticktick|Proton Mail|Slack|class.org.keepassxc.KeePassXC)$"
    #   "workspace 8 silent, class:^(discord|Signal)$"
    #   "workspace 9 silent, class:^(Spotify)$"
    # ];

    bind = [
      "$mainMod, 1, workspace, ${toString workspaces.browser}"
      "$mainMod, 2, workspace, ${toString workspaces.code}"
    ];
  };
}
