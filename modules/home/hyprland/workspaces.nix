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
    config.cursor = {
      default_monitor = "DP-2";
      no_hardware_cursors = true;
    };

    # Desktop monitor configuration (amanita).
    # Laptop monitor config is in hosts/cordyceps/default.nix.
    # Lua config: one table per output instead of the positional comma string,
    # so bitdepth/transform/mirror are named fields rather than trailing pairs.
    monitor = [
      # bitdepth 10: forces max bpc 10, which pushes 240Hz over HBR3 and makes
      # amdgpu enable DSC (~16bpp) instead of falling back to 8 bpc.
      {
        output = "DP-2";
        mode = "2560x1440@239.972000";
        position = "0x0";
        scale = 1;
        bitdepth = 10;
      }
      {
        output = "DP-1";
        mode = "3840x2160@120.00000";
        position = "-2560x0";
        scale = 1.5;
      }
      {
        output = "HDMI-A-2";
        mode = "preferred";
        position = "2560x0";
        scale = 1;
        transform = 3;
      }
      # Mirror DP-1 onto the AVR/HDMI-A-1 (dormant while unplugged).
      # Note: mirroring copies DP-1's framebuffer as-is (no re-render); differing
      # aspect ratios will stretch/squish.
      # See patches/hyprland-mirror-weakptr.patch — unplugging DP-1 while this is
      # live SEGVs an unpatched Hyprland.
      {
        output = "HDMI-A-1";
        mode = "preferred";
        position = "auto";
        scale = 1;
        mirror = "DP-1";
      }
    ];

    # Was `workspace = [ "1, monitor:DP-1, persistent:true, ..." ]`.
    workspace_rule =
      if host == "amanita" then
        [
          # DP-1 (Left 4K monitor)
          {
            workspace = "1";
            monitor = "DP-1";
            persistent = true;
            layout_opts.orientation = "top";
          }
          {
            workspace = "2";
            monitor = "DP-1";
            persistent = true;
          }
          {
            workspace = "3";
            monitor = "DP-1";
            persistent = true;
          }

          # DP-2 (Center main monitor)
          {
            workspace = "4";
            monitor = "DP-2";
            persistent = true;
            default = true;
            default_name = "main";
          }
          {
            workspace = "5";
            monitor = "DP-2";
            persistent = true;
          }
          {
            workspace = "6";
            monitor = "DP-2";
            persistent = true;
          }

          # HDMI-A-2 (Right vertical monitor) — scrolling tape, grows downward
          {
            workspace = "7";
            monitor = "HDMI-A-2";
            persistent = true;
            default = true;
            layout = "scrolling";
          }
          {
            workspace = "8";
            monitor = "HDMI-A-2";
            persistent = true;
            layout = "scrolling";
          }
          {
            workspace = "9";
            monitor = "HDMI-A-2";
            persistent = true;
            layout = "scrolling";
          }
        ]
      else
        [
          # Default workspace assignments
          {
            workspace = toString workspaces.browser;
            monitor = "DP-2";
          }
          {
            workspace = toString workspaces.code;
            monitor = "DP-1";
          }
          {
            workspace = toString workspaces.communication;
            monitor = "HDMI-A-1";
          }
        ];

    # NOTE: the old "$mainMod, 1/2, workspace, N" binds that lived here were exact
    # duplicates of the [0-9] workspace binds in keybinds.nix (browser=1, code=2).
    # Dropped in the Lua migration — hl.bind on an already-bound key is a conflict,
    # not a silently-ignored duplicate like hyprlang allowed.
  };
}
