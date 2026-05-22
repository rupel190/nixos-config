{ pkgs, config, ... }:
{
  home.packages = [ pkgs.onedrive ];

  # Declare symlinks into ~/.claude so OneDrive syncs Claude data across machines.
  # mkOutOfStoreSymlink is required because ~/.claude is runtime state, not in the Nix store.
  home.file."OneDrive/symlinked/claude/projects".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/projects";
  home.file."OneDrive/symlinked/claude/plugins".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/plugins";

  # OneDrive sync service (abraunegg/onedrive)
  systemd.user.services.onedrive = {
    Unit = {
      Description = "OneDrive sync service";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.onedrive}/bin/onedrive --monitor";
      Restart = "on-failure";
      RestartSec = 3;
      TimeoutStopSec = 8;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
