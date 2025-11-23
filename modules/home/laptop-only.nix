{ pkgs, ... }:
{
  # Laptop-specific home-manager packages
  # Imported by hosts/cordyceps (laptop)

  home.packages = with pkgs; [
    poweralertd # Battery notification daemon
    # Add other laptop-specific tools here (brightnessctl, etc.)
  ];
}
