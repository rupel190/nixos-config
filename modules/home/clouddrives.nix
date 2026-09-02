{ pkgs, ... }:
{
  home.packages = [ pkgs.onedrive ];

  # No ~/.config/onedrive/config at all — plain defaults (sync_dir ~/OneDrive,
  # the built-in skip_file list). Claude state is synced by claude-sync via R2,
  # not through here; the archived symlinked/claude copy has been deleted from
  # OneDrive, so the skip_dir rule that protected it is no longer needed.
  #
  # History: ~/.claude/{projects,plugins} used to be mkOutOfStoreSymlink'd into
  # ~/OneDrive. It never worked — the monitor skipped *.jsonl so no session log
  # ever moved, and the second onedrive instance meant to carry them failed on
  # every run from 2026-07-19 with "--no-remote-delete can only be used with
  # --upload-only". What it did sync was ~19k events of plugin cache churn.
  # Setting skip_file also silently REPLACED onedrive's built-in defaults
  # (~*|.~*|*.tmp|*.swp|*.partial) rather than extending them.

  # Main OneDrive monitor: real-time sync of ~/OneDrive.
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
