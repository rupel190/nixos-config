# NixOS Configuration

A modular, flake-based NixOS configuration for two machines, built around Hyprland, Home Manager
and a curated set of development and desktop tools. Host-specific behaviour is gated on a `host`
specialArg rather than split into separate trees, so both machines share one module set.

## Features

- **Flake-based** configuration for reproducible system builds
- **Two hosts** — a desktop and a laptop — sharing modules, gated by `lib.optionals (host == ...)`
- **Hyprland** (tracking git `main`, Lua config) with custom keybinds, workspaces and window rules
- **Home Manager** for declarative user environment management
- **AGS 3 / Astal** status bar running as a systemd user unit
- **ragenix** for age-encrypted secrets committed to the repo

## Structure

```
.
├── flake.nix              # Inputs, both nixosConfigurations
├── home.nix               # Home Manager entry point
├── hosts/
│   ├── amanita/           # Desktop
│   └── cordyceps/         # Laptop
├── secrets/               # age-encrypted secrets + secrets.nix (ragenix)
└── modules/
    ├── core/              # System-level modules
    │   ├── bootloader.nix
    │   ├── comfyui.nix        # amanita only: ComfyUI on ROCm + model fetcher
    │   ├── comfy-edit.py      # headless driver for comfyui.nix
    │   ├── greetd.nix         # greetd + tuigreet TTY login
    │   ├── hardware.nix
    │   ├── network.nix
    │   ├── nh.nix             # nh helper + auto-cleanup
    │   ├── pipewire.nix
    │   ├── program.nix        # dconf and friends
    │   ├── security.nix
    │   ├── services.nix
    │   ├── steam.nix
    │   ├── system.nix
    │   ├── user.nix
    │   ├── virtualization.nix
    │   ├── wayland.nix        # Portals
    │   └── xserver.nix
    └── home/              # User-level modules
        ├── hyprland/          # config, keybinds, workspaces, variables,
        │                      # hypridle, hyprlock
        ├── ags/               # Status bar (AGS 3 / Astal, GTK4)
        ├── btop/              # Resource monitor
        ├── cava/              # Audio visualizer
        ├── discord/           # Discord with theming
        ├── dotfiles/          # nvim, yazi, tridactyl, gh, …
        ├── bat.nix            # Better cat
        ├── browser.nix        # Zen Browser
        ├── claude.nix         # Claude Code + MCP servers
        ├── clouddrives.nix    # OneDrive sync
        ├── darya.nix          # Disk usage visualizer
        ├── fastfetch.nix      # Fetch tool + weather panel
        ├── fish.nix           # Shell
        ├── fzf.nix            # Fuzzy finder
        ├── git.nix            # Version control
        ├── gtk.nix            # GTK theming
        ├── laptop-only.nix    # cordyceps only: brightness, battery, gestures
        ├── lazygit.nix        # Git TUI
        ├── mpv.nix            # Media player
        ├── packages.nix       # Additional packages + swaync service
        ├── pi-backup.nix      # amanita only: weekly RPi backup pull
        ├── plasticity.nix     # Plasticity CAD (AppImage)
        ├── pulsemixer.nix     # Audio mixer (patched selection highlight)
        ├── qbz.nix            # Qobuz hi-fi player (AppImage)
        ├── spicetify.nix      # Spotify theming
        ├── surge.nix          # Download manager (TUI)
        ├── tera.nix           # Terminal radio player
        ├── vicinae.nix        # Launcher + browser tab integration
        ├── wezterm.nix        # Terminal emulator (mux server/client)
        ├── xdg-mimes.nix      # File associations
        └── yazi.nix           # Terminal file manager
```

`obsidian.nix`, `waypaper.nix` and `default.desktop.nix` exist but are not imported — see the
"Skipped" block in `modules/home/default.nix`.

## Hosts

### amanita (Desktop)

- Ryzen 7 7800X3D + Radeon RX 9070 XT (RDNA 4 / GFX1201) on RADV
- Three outputs: `DP-2` (main, 240 Hz), `DP-1`, `HDMI-A-2`
- Multiple filesystem mounts for storage and backups
- Weekly Raspberry Pi backup pull (`pi-backup.nix`)
- Local image generation via `comfyui.nix` (host-gated in `modules/core/default.nix`)

### cordyceps (Laptop)

- Framework 13, fully configured (no longer commented out)
- `laptop-only.nix`: brightness keys, battery management, touchpad settings
- Touchscreen gestures via **hyprgrass**, pinned to follow the flake's Hyprland so the plugin ABI matches

## Keybinds

`SUPER` is the mod key. Deep-system actions use `CTRL+SUPER+ALT` so they can't fire by accident.
Full list in `modules/home/hyprland/keybinds.nix`.

| Key | Action |
| --- | --- |
| `SUPER+T` | Terminal — focuses the running WezTerm mux client, or connects if none |
| `SUPER+W` | Fresh standalone terminal (own process, not the mux) |
| `SUPER+E` | Yazi file manager in a new window |
| `SUPER+R` / `SUPER+RETURN` | Vicinae launcher |
| `SUPER+C` / `SUPER+F` | Close window / toggle floating |
| `SUPER+N` | Notification center (swaync) |
| `SUPER+H/J/K/L` | Move focus (add `ALT` to move the window) |
| `SUPER+I` / `SUPER+O` | Cycle workspaces (add `ALT` to bring the window) |
| `SUPER+1..0` | Switch workspace (add `ALT` to move the window there) |
| `SUPER+SPACE` | Scratchpad (special workspace) |
| `SUPER+S` | Region screenshot to clipboard |
| `SUPER+SHIFT+S` | Region screenshot into swappy |
| `CTRL+ALT+SHIFT+S` | Whole monitor under the cursor into swappy |
| `SUPER+ALT+S` | Start screen recording (portal picker) |
| `SUPER+,` / `SUPER+.` | Scrolling layout: cycle column width |
| `SUPER+;` | Scrolling layout: promote window to its own column |
| `SUPER+[` / `SUPER+]` | Scrolling layout: consume / expel column |
| `CTRL+SUPER+ALT+L` | Lock now |
| `CTRL+SUPER+ALT+M` | Monitors off |
| `CTRL+SUPER+ALT+I` | Toggle idle inhibit |
| `SUPER+F5` | Reload Hyprland config |

WezTerm runs a mux server with named workspaces (`default`, `system`, `recustomize`, `nixos`,
`beamng`), so closing a window keeps the session alive — `SUPER+T` walks back into it. `SUPER+W`
and `SUPER+E` deliberately spawn standalone processes with their own app_ids
(`org.wezfurlong.wezterm.scratch` / `.yazi`) so the reattach never grabs the wrong window.

## Key Software

### Window Manager & Desktop

- **Hyprland** — tiling Wayland compositor (git `main`, Lua config)
- **AGS 3 / Astal** — status bar and overlays (GTK4)
- **swaync** — notification daemon
- **Vicinae** — application launcher
- **greetd + tuigreet** — TTY login manager

### Terminal & CLI Tools

- **WezTerm** — terminal emulator, run as mux server + GUI clients
- **Fish** — shell
- **Yazi** — file manager
- **btop** / **darya** — resource and disk-usage monitors
- **bat**, **fzf**, **fastfetch**
- **pulsemixer** — audio mixer
- **Surge** — download manager TUI
- **tera** — terminal radio player

### Development

- **Claude Code** — AI coding assistant, plus a WezTerm image MCP server
- **Claude Desktop**
- **Git**, **Lazygit**
- **Neovim** (LazyVim config in `dotfiles/`)

### Applications

- **Zen Browser** — privacy-focused browser
- **Discord** (themed), **Spotify** (via Spicetify, with the Singify karaoke extension)
- **Qobuz (qbz)** — hi-fi music player
- **MPV** — media player
- **Plasticity** — CAD
- **Steam** — with Proton and Millennium
- **Affinity** suite via `affinity-nix`

### System Features

- **PipeWire** — audio server
- **Virtualization** — KVM/QEMU
- **nix-flatpak** — declarative Flatpaks
- **ragenix** — age-encrypted secrets

## Flake Inputs

| Input | Purpose |
| --- | --- |
| `nixpkgs` | NixOS unstable |
| `home-manager` | User environment management |
| `hyprland` | Compositor (git `main`) |
| `hyprland-plugins`, `hyprgrass` | Plugins; hyprgrass = touchscreen gestures (laptop) |
| `hyprpaper` | Wallpaper daemon |
| `ags` | AGS 3.x — nixpkgs ships 2.3.0 with an incompatible API |
| `wezterm` | Terminal emulator |
| `zen-browser` | Privacy-focused browser (auto-updates daily) |
| `yazi-plugins` | Yazi plugins (source only) |
| `spicetify-nix`, `singify` | Spotify theming + UltraStar karaoke extension |
| `nix-flatpak` | Flatpak integration |
| `claude-code`, `claude-desktop` | AI coding assistant and desktop app |
| `wezterm-image-mcp` | MCP server showing images in a side WezTerm pane (git+ssh) |
| `millennium` | Steam Homebrew |
| `ragenix` | age secret management |
| `surge` | Download manager |
| `plasticityAppImage` | Plasticity CAD |
| `affinity-nix` | Affinity suite (upstream pin kept for the Garnix cache) |

## Installation

### First-time Setup

1. Clone this repository:

```bash
git clone git@github.com:rupel190/nixos-config.git ~/projects/nixos-config
cd ~/projects/nixos-config
```

2. Update hardware configuration:

```bash
nixos-generate-config --show-hardware-config > hosts/amanita/hardware-configuration.nix
```

3. Build and switch:

```bash
sudo nixos-rebuild switch --flake .#amanita   # or .#cordyceps
```

### Updating the System

```bash
# Update all flake inputs
nix flake update

# Or a single input
nix flake update hyprland

# Rebuild with new configuration
sudo nixos-rebuild switch --flake .#amanita
```

Note: `github:` inputs are fetched as tarballs that GitHub secondary-rate-limits (HTTP 429 even
when authenticated). Inputs that hit this use `git+ssh://` instead.

### Using nh (Nix Helper)

```bash
# Update and rebuild
nh os switch

# Clean old generations
nh clean all
```

## Secrets

Secrets live in `secrets/` as age-encrypted files, managed with **ragenix** and readable by the
host keys listed in `secrets/secrets.nix`:

`RULES` must be set: ragenix defaults to `./secrets.nix`, but the manifest lives in
`secrets/`. The identity is `id_ed25519_fresh` — that is the key listed as `amanita-rupel`,
not the default `~/.ssh/id_ed25519` (which is `rupel@level-8` and is not a recipient).

```bash
# Edit a secret in place
RULES=secrets/secrets.nix ragenix -e secrets/claude-sync-r2.age -i ~/.ssh/id_ed25519_fresh

# Re-key everything after adding a host or key. Rewrites EVERY secret, not just
# the ones whose recipients changed, so expect the whole secrets/ dir to show as
# modified — identical plaintext always re-encrypts to different bytes.
RULES=secrets/secrets.nix ragenix --rekey -i ~/.ssh/id_ed25519_fresh
```

Adding a machine: append its **host** key (`/etc/ssh/ssh_host_ed25519_key.pub`, not a user
key) to `secrets/secrets.nix`, list it on the secrets it should read, then `--rekey` from a
machine that can already decrypt.

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
    username = "rupel";
    host = "newhostname";
  };
  modules = [
    ./hosts/newhostname
  ];
};
```

The `host` argument is what module-level gating keys off, e.g.
`lib.optionals (host == "cordyceps") [ ./laptop-only.nix ]`.

### Adding New Modules

1. Create a new `.nix` file in `modules/core/` (system) or `modules/home/` (user)
2. Import it in the respective `default.nix`
3. Configure the module with your settings

## Notes

- AMD GPU: Electron and Chromium apps on GFX1201 need explicit GL/ANGLE flags — see the comments
  in `spicetify.nix` and `steam.nix` before changing them
- Hyprland tracks git `main`, which is Lua-only; `hyprctl dispatch` takes Lua, not the legacy
  comma-string form. `hyprctl repl '<code>'` is handy for testing config snippets live
- Multiple storage devices are automatically mounted on boot
- Both hosts are active; `laptop-only.nix` and `pi-backup.nix` are the host-gated modules

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Built with the NixOS community's incredible tools and flakes.
