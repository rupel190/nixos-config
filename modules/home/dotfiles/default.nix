{ pkgs, ... }:
{
  # Unmanaged app configs — deployed as-is from this repo.
  # These aren't "nixified" yet, just version-controlled and synced.

  xdg.configFile = {
    "nvim" = { source = ./nvim; recursive = true; };
    "tridactyl" = { source = ./tridactyl; recursive = true; };
    "keepassxc" = { source = ./keepassxc; recursive = true; };

    # Blockbench's own Preferences stay unmanaged: Electron rewrites that file whenever it likes,
    # and a linked copy made the next switch fail on the backup.
    # jasonjgardner's MCP plugin: while Blockbench is open, Claude builds models in its window.
    # Loaded once by hand (File › Plugins › Load Plugin from File, MCP port 3917 in Settings ›
    # General) and registered with `claude mcp add -s user --transport http blockbench
    # http://localhost:3917/bb-mcp`. Port 3000, the default, is taken on amanita.
    "Blockbench/plugins/mcp.js".source = pkgs.fetchurl {
      url = "https://github.com/jasonjgardner/blockbench-mcp-plugin/releases/download/v1.10.1/mcp.js";
      hash = "sha256-yvlFQOUCV+rrWqUatLNLVqpqwlig+MC+4gJcLPGNXbk=";
    };
  };
}
