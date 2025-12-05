{ pkgs, inputs, ... }:
{
  home.packages = [
    # Claude Code from flake (auto-updating via GitHub Actions)
    # Provides pre-built binaries via Cachix for faster installation
    inputs.claude-code.packages.${pkgs.system}.default

    # Alternative: Use stable version from nixpkgs (slower updates)
    # pkgs.claude-code
    pkgs.claude-monitor
  ];

  # Optional: Set up Cachix for pre-built binaries
  # Run: cachix use claude-code
  # This significantly speeds up installation by using pre-built binaries
  # instead of building from source
}
