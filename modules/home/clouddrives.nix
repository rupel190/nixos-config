{ pkgs, config, ... }:
{
  home.packages = [ pkgs.onedrive ];

  # Declare symlinks into ~/.claude so OneDrive syncs Claude data across machines.
  # mkOutOfStoreSymlink is required because ~/.claude is runtime state, not in the Nix store.
  home.file."OneDrive/symlinked/claude/projects".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/projects";
  home.file."OneDrive/symlinked/claude/plugins".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/plugins";

  # Main onedrive config: skip JSONL files so active Claude sessions don't cause churn.
  # JSONL conversation logs are handled separately by the onedrive-claude-sync timer below.
  home.file.".config/onedrive/config".text = ''
    skip_file = "*.jsonl"
  '';

  # Second onedrive instance config: only syncs the claude projects directory,
  # no skip_file so JSONL files are included. Shares the auth token with the main instance.
  home.file.".config/onedrive-claude/config".text = ''
    sync_dir = "${config.home.homeDirectory}/OneDrive"
  '';
  home.file.".config/onedrive-claude/sync_list".text = ''
    symlinked/claude/projects
  '';
  home.file.".config/onedrive-claude/refresh_token".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/onedrive/refresh_token";

  # Main OneDrive monitor: syncs everything in real-time except JSONL files.
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

  # Periodic JSONL sync: uploads/downloads Claude conversation logs every 20 minutes.
  # Uses --no-remote-delete so it never removes files the main instance manages.
  systemd.user.services.onedrive-claude-sync = {
    Unit = {
      Description = "Sync Claude conversation logs via OneDrive";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.onedrive}/bin/onedrive --confdir %h/.config/onedrive-claude --sync --no-remote-delete";
    };
  };

  systemd.user.timers.onedrive-claude-sync = {
    Unit.Description = "Periodic sync of Claude conversation logs";
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "20min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
