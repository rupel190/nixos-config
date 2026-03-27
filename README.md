# NixOS Configuration

A modular, flake-based NixOS configuration featuring Hyprland, Home Manager, and a curated set of development and desktop tools.

## Features

- **Flake-based** configuration for reproducible system builds
- **Hyprland** window manager with custom keybinds and workspaces
- **Home Manager** for declarative user environment management
- **Modular structure** for easy customization and maintenance
- **Multi-host support** for desktop and laptop configurations

## Structure

```
.
├── flake.nix              # Main flake configuration
├── home.nix               # Home Manager entry point
├── hosts/
│   ├── amanita/           # Desktop configuration
│   └── cordyceps/         # Laptop configuration
└── modules/
    ├── core/              # System-level modules
    │   ├── bootloader.nix
    │   ├── hardware.nix
    │   ├── network.nix
    │   ├── pipewire.nix
    │   ├── security.nix
    │   ├── services.nix
    │   ├── steam.nix
    │   ├── system.nix
    │   ├── user.nix
    │   ├── virtualization.nix
    │   ├── wayland.nix
    │   └── xserver.nix
    └── home/              # User-level modules
        ├── hyprland/      # Hyprland WM configuration
        ├── ags/           # Widget bar system
        ├── bat.nix        # Better cat
        ├── browser.nix    # Zen Browser
        ├── btop/          # Resource monitor
        ├── cava/          # Audio visualizer
        ├── claude.nix     # AI coding assistant
        ├── discord/       # Discord with theming
        ├── fish.nix       # Shell
        ├── fzf.nix        # Fuzzy finder
        ├── git.nix        # Version control
        ├── gtk.nix        # GTK theming
        ├── lazygit.nix    # Git TUI
        ├── mpv.nix        # Media player
├── spicetify.nix  # Spotify theming
        ├── packages.nix   # Additional packages
        ├── swaync/        # Notification daemon
        ├── wezterm.nix    # Terminal emulator
        ├── xdg-mimes.nix  # File associations
        └── yazi.nix       # Terminal file manager
```

## Hosts

### amanita (Desktop)

- AMD GPU (RX 9070 XT) with Vulkan/RADV
- Multiple filesystem mounts for storage and backups
- Full Wayland setup with Hyprland

### cordyceps (Laptop)

- Currently in development (configuration exists but commented out)
- Will include laptop-specific modules (battery management, brightness controls)

## Key Software

### Window Manager & Desktop

- **Hyprland** - Tiling Wayland compositor
- **AGS** - Widget system for bars and overlays
- **swaync** - Notification daemon
- **Waypaper** - Wallpaper management

### Terminal & CLI Tools

- **WezTerm** - Terminal emulator
- **Fish** - Shell
- **Yazi** - File manager
- **btop** - System monitor
- **Cava** - Audio visualizer
- **bat** - Syntax-highlighted cat
- **fzf** - Fuzzy finder

### Development

- **Claude Code** - AI coding assistant
- **Git** with custom configuration
- **Lazygit** - Git TUI
- **Neovim** (using Lazyvim)

### Applications

- **Zen Browser** - Privacy-focused browser
- **Discord** - Communication (themed)
- **Spotify** - Music (via Spicetify)
- **MPV** - Media player
- **Steam** - Gaming platform

### System Features

- **PipeWire** - Audio server
- **Virtualization** - KVM/QEMU support
- **Steam** - Gaming with Proton
- **Home Manager** - Declarative user environment

## Flake Inputs

- `nixpkgs` - NixOS unstable
- `home-manager` - User environment management
- `hyprland` - Wayland compositor
- `hyprland-plugins` - Additional Hyprland functionality
- `wezterm` - Terminal emulator
- `zen-browser` - Privacy-focused browser (auto-updates daily)
- `yazi-plugins` - Yazi file manager plugins
- `spicetify-nix` - Spotify theming
- `nix-flatpak` - Flatpak integration
- `claude-code` - AI coding assistant

## Installation

### First-time Setup

1. Clone this repository:

```bash
git clone https://github.com/yourusername/nixos-config.git /etc/nixos
cd /etc/nixos
```

2. Update hardware configuration:

```bash
nixos-generate-config --show-hardware-config > hosts/amanita/hardware-configuration.nix
```

3. Build and switch:

```bash
sudo nixos-rebuild switch --flake .#amanita
```

### Updating the System

```bash
# Update flake inputs
nix flake update

# Rebuild with new configuration
sudo nixos-rebuild switch --flake .#amanita
```

### Using nh (Nix Helper)

This configuration includes `nh` for easier system management:

```bash
# Update and rebuild
nh os switch

# Clean old generations
nh clean all
```

## Customization

### Adding a New Host

1. Create a new directory under `hosts/`:

```bash
mkdir -p hosts/newhostname
```

2. Create `hosts/newhostname/default.nix`:

```nix
{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./../../modules/core
  ];

  networking.hostName = "newhostname";
}
```

3. Add the host to `flake.nix`:

```nix
nixosConfigurations.newhostname = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = {
    inherit inputs self;
    username = "yourusername";
    host = "newhostname";
  };
  modules = [
    ./hosts/newhostname
  ];
};
```

### Adding New Modules

1. Create a new `.nix` file in `modules/core/` (system) or `modules/home/` (user)
2. Import it in the respective `default.nix`
3. Configure the module with your settings

## Notes

- AMD GPU users: The configuration includes specific environment variables for Vulkan and Wayland
- Multiple storage devices are automatically mounted on boot
- Laptop configuration (cordyceps) is currently commented out in the flake

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Built with the NixOS community's incredible tools and flakes.
