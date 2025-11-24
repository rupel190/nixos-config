{ pkgs, ... }:
{
  # OneDrive sync service (abraunegg/onedrive)
  services.onedrive = {
    enable = true;
    package = pkgs.onedrive;
  };
}
