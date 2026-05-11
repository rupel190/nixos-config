{ pkgs, inputs, ... }:
let
  proton-drive-sync = inputs.proton-drive-sync.packages.${pkgs.system}.default;
in
{
  home.packages = [
    pkgs.onedrive
    proton-drive-sync
  ];

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
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Proton Drive sync daemon
  # One-time setup after first build (with KeePassXC open):
  #   proton-drive-sync setup
  #   proton-drive-sync auth
  # Restarts on failure to handle KeePassXC not yet unlocked at login.
  systemd.user.services.proton-drive-sync = {
    Unit = {
      Description = "Proton Drive sync daemon";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${proton-drive-sync}/bin/proton-drive-sync start";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
