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

    wezterm.url = "github:wez/wezterm?dir=nix";
    zen-browser.url = "github:MarceColl/zen-browser-flake";

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
        ];
      };

      # Laptop (uncomment when you set it up)
      # nixosConfigurations.cordyceps = nixpkgs.lib.nixosSystem {
      #   system = "x86_64-linux";
      #   specialArgs = {
      #     inherit inputs self;
      #     username = "rupel";
      #     host = "cordyceps";
      #   };
      #   modules = [
      #     ./hosts/cordyceps
      #   ];
      # };
    };
}
