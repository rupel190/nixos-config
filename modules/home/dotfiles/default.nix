{ ... }:
{
  # Unmanaged app configs — deployed as-is from this repo.
  # These aren't "nixified" yet, just version-controlled and synced.

  xdg.configFile = {
    "nvim" = { source = ./nvim; recursive = true; };
    "tridactyl" = { source = ./tridactyl; recursive = true; };
    "keepassxc" = { source = ./keepassxc; recursive = true; };
    "Blockbench" = { source = ./Blockbench; recursive = true; };
  };
}
