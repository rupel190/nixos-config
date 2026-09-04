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
    # Touchscreen gestures (cordyceps FW13 touch panel). Separate repo from the
    # official hyprland-plugins; must follow our git Hyprland so the plugin ABI
    # matches (the nixpkgs hyprgrass is built against nixpkgs' Hyprland).
    hyprgrass = {
      url = "github:horriblename/hyprgrass";
      inputs.hyprland.follows = "hyprland";
    };
    hyprpaper = {
      url = "github:hyprwm/hyprpaper";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # AGS 3.x — the scaffolding CLI that bundles our TypeScript/JSX into a GJS
    # script. Not optional: nixpkgs ships 2.3.0, whose API is `astal/gtk3`
    # (GTK3, `Variable().poll()`, `className=`), while modules/home/ags is
    # written against v3's `ags/gtk4`. The flake also ships pre-generated @girs
    # types — `ags init` otherwise shells out to `npx @ts-for-gir/cli`, which
    # can't work in a sandboxed build.
    # Deliberately does NOT set `inputs.astal.follows`: ags pins the exact astal
    # rev its bundled type definitions were generated against, and overriding it
    # desyncs the two.
    ags = {
      url = "github:aylur/ags";
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

    # UltraStar karaoke Spicetify extension. Builds karaoke.js from source
    # (bun, no npm deps); consumed in modules/home/spicetify.nix. Update with
    # `nix flake update singify` after pushing changes to the singify repo.
    singify = {
      url = "github:rupel190/singify";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    claude-code.url = "github:sadjow/claude-code-nix";

    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # MCP server that shows images in a side WezTerm pane (consumed in
    # modules/home/claude.nix). Source-only (no flake.nix), so flake = false.
    # git+ssh (not github:) so fetches go over your SSH key and skip GitHub's
    # tarball/codeload rate limit (which 429s even when authenticated). Update
    # with `nix flake update wezterm-image-mcp` after pushing to the repo.
    wezterm-image-mcp = {
      url = "git+ssh://git@github.com/rupel190/wezterm-image-mcp";
      flake = false;
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

    plasticityAppImage = {
      url = "github:EntropyWorks/plasticityAppImage";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # No nixpkgs.follows: keeps the upstream pin so Garnix binary cache hits
    # (avoids compiling ElementalWarrior's patched Wine fork locally).
    affinity-nix.url = "github:mrshmllow/affinity-nix";
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
