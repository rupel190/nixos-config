{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    hyprpaper = {
      url = "github:hyprwm/hyprpaper";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wezterm.url = "github:wez/wezterm?dir=nix";
    zen-browser.url = "github:youwen5/zen-browser-flake"; # Auto-updates daily

    yazi-plugins = {
      url = "github:yazi-rs/plugins";
      flake = false;
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    claude-code.url = "github:sadjow/claude-code-nix";

    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Steam Homebrew
    millennium.url = "github:SteamClientHomebrew/Millennium?dir=packages/nix";

    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    surge = {
      url = "github:SurgeDM/Surge";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      hyprland,
      ...
    }@inputs:
    {
      # Desktop
      nixosConfigurations.amanita = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs self;
          username = "rupel";
          host = "amanita";
        };
        modules = [
          ./hosts/amanita
          inputs.ragenix.nixosModules.default
        ];
      };

      # Laptop
      nixosConfigurations.cordyceps = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs self;
          username = "rupel";
          host = "cordyceps";
        };
        modules = [
          ./hosts/cordyceps
          inputs.ragenix.nixosModules.default
        ];
      };
    };
}
