# NixOS Configuration

A modular, flake-based NixOS configuration for three machines: two workstations built around
Hyprland, Home Manager and a curated set of development and desktop tools, plus a lean touch
panel for the wall. The workstations share one module set, and host-specific behaviour is gated
on a `host` specialArg rather than split into separate trees.

## Features

- **Flake-based** configuration for reproducible system builds
- **Three hosts** — a desktop and a laptop sharing modules (gated by `lib.optionals (host == ...)`),
  and a wall tablet that deliberately imports neither shared tree
- **Hyprland** (tracking git `main`, Lua config) with custom keybinds, workspaces and window rules,
  plus local patches in `patches/`
- **Home Manager** for declarative user environment management
- **AGS 3 / Astal** status bar with a system tray, running as a systemd user unit
- **ragenix** for age-encrypted secrets committed to the repo
- **disko** for the wall tablet's declarative disk layout

## Structure

```
.
├── flake.nix              # Inputs, all three nixosConfigurations
├── home.nix               # Home Manager entry point (workstations)
├── patches/               # Local Hyprland patches (idle inhibit, mirror hotplug)
├── hosts/
│   ├── amanita/           # Desktop
│   ├── cordyceps/         # Laptop
│   └── mycena/            # Wall tablet: disko, Phosh, Home Assistant, own home.nix
├── secrets/               # age-encrypted secrets + secrets.nix (ragenix)
└── modules/
    ├── core/              # System-level modules (workstations)
    │   ├── bootloader.nix
    │   ├── greetd.nix         # greetd + tuigreet TTY login
    │   ├── hardware.nix
    │   ├── network.nix
    │   ├── nh.nix             # nh helper + auto-cleanup
    │   ├── pipewire.nix
    │   ├── printing.nix       # CUPS + Bluetooth label printer
    │   ├── ptouch/            # Label printer backend and `label` tool
    │   ├── program.nix        # dconf and friends
    │   ├── secrets.nix        # agenix secrets shared by every workstation
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
        ├── audio-switch/      # Default-output ring (bar click + CTRL+SUPER+ALT+A)
        ├── btop/              # Resource monitor
        ├── cava/              # Audio visualizer
        ├── claude-hooks/      # Claude Code hooks (notifications, status), shellchecked
        ├── discord/           # Vesktop (Discord + Vencord)
        ├── dotfiles/          # nvim, yazi, tridactyl, gh, …
        ├── projects/          # Declared ~/projects checkouts + drift audit
        ├── say-clip/          # Read-aloud script (kokoro TTS daemon)
        ├── bat.nix            # Better cat
        ├── browser.nix        # Zen Browser
        ├── claude.nix         # Claude Code + MCP servers + statusline
        ├── claude-sync.nix    # Sync ~/.claude across machines
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
        ├── opencode.nix       # Provider-agnostic coding agent
        ├── packages.nix       # Additional packages
        ├── pi-backup.nix      # amanita only: weekly RPi backup pull
        ├── plasticity.nix     # Plasticity CAD (AppImage)
        ├── pulsemixer.nix     # Audio mixer (patched selection highlight)
        ├── say-clip.nix       # Packages say-clip
        ├── spicetify.nix      # Spotify theming
        ├── surge.nix          # Download manager (TUI)
        ├── swaync.nix         # Notification centre, themed to match the bar
        ├── tera.nix           # Terminal radio player
        ├── udiskie.nix        # amanita only: automount removable drives, tray icon
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
- Storage: internal drives are declared in `hosts/amanita/default.nix`; anything plugged in
  (USB sticks, drives on a SATA adapter) is automounted by udiskie under `/run/media/<user>/`,
  owned by the user — no sudo
- **smartd** watches every SATA and NVMe drive and runs a weekly short self-test; warnings arrive
  as desktop notifications (system bus → `systembus-notify` → swaync)
- Weekly Raspberry Pi backup pull (`pi-backup.nix`)

### cordyceps (Laptop)

- Framework 13
- `laptop-only.nix`: brightness keys, battery management, touchpad settings
- Touchscreen gestures via **hyprgrass**, pinned to follow the flake's Hyprland so the plugin ABI matches

### mycena (Wall tablet)

- Surface Book (1st gen) on the linux-surface kernel via `nixos-hardware`, for touch and stylus
- Deliberately imports neither `modules/core` nor `modules/home`: no Hyprland, no secrets, its own
  small `home.nix`
- **Phosh** session, because on the wall there is no keyboard or mouse, only touch
- Hosts **Home Assistant** for now (`homeassistant.nix`, kept separate so it can move)
- Disk layout declared with **disko**; installed and rebuilt remotely from amanita

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
| `ALT+TAB` / `ALT+SHIFT+TAB` | Cycle workspaces |
| `SUPER+1..0` | Switch workspace (add `ALT` to move the window there) |
| `SUPER+SPACE` | Scratchpad (special workspace); `SUPER+SHIFT+SPACE` sends the window there |
| `SUPER+S` | Region screenshot to clipboard |
| `SUPER+SHIFT+S` | Region screenshot into swappy |
| `CTRL+ALT+SHIFT+S` | Whole monitor under the cursor into swappy |
| `SUPER+ALT+S` / `SUPER+ALT+SHIFT+S` | Start / stop screen recording (portal picker) |
| `SUPER+SHIFT+R` | Read the clipboard aloud (say-clip) |
| `SUPER+,` / `SUPER+.` | Scrolling layout: cycle column width |
| `SUPER+;` | Scrolling layout: promote window to its own column |
| `SUPER+[` / `SUPER+]` | Scrolling layout: consume / expel column |
| `CTRL+SUPER+ALT+L` | Lock now |
| `CTRL+SUPER+ALT+M` | All monitors off |
| `CTRL+SUPER+ALT+1..3` | One monitor off (amanita) |
| `CTRL+SUPER+ALT+4` | AV receiver output: mirror `DP-1` ⇄ own desktop (amanita) |
| `CTRL+SUPER+ALT+A` | Cycle the audio output |
| `CTRL+SUPER+ALT+I` | Toggle idle inhibit |
| `SUPER+F5` | Reload Hyprland config |

Idle: monitors blank after 10 minutes, the session locks after 20.

WezTerm runs a mux server that starts two workspaces: `default`, with a `claude --resume` tab
per active project plus a scratch tab, and `system`, with pulsemixer, tera and btop. Closing a
window keeps the session alive — `SUPER+T` walks back into it. `SUPER+W` and `SUPER+E` deliberately spawn
standalone processes with their own app_ids (`org.wezfurlong.wezterm.scratch` / `.yazi`) so the
reattach never grabs the wrong window.

## Key Software

### Window Manager & Desktop

- **Hyprland** — tiling Wayland compositor (git `main`, Lua config)
- **AGS 3 / Astal** — status bar and overlays (GTK4), including the system tray
- **swaync** — notification centre
- **Vicinae** — application launcher
- **greetd + tuigreet** — TTY login manager
- **udiskie** — removable-drive automounting (amanita)

### Terminal & CLI Tools

- **WezTerm** — terminal emulator, run as mux server + GUI clients
- **Fish** — shell
- **Yazi** — file manager
- **btop** / **darya** — resource and disk-usage monitors
- **bat**, **fzf**, **fastfetch**
- **pulsemixer** — audio mixer
- **audio-switch** — cycles the default output around a declared ring of devices; same binary
  behind the bar's speaker icon and `CTRL+SUPER+ALT+A`
- **say-clip** — reads the clipboard aloud through a warm kokoro TTS daemon
- **Surge** — download manager TUI
- **tera** — terminal radio player

### Development

- **Claude Code** — AI coding assistant with MCP servers (incl. a WezTerm image pane), hooks,
  a usage statusline and skills pinned as flake inputs
- **Claude Desktop**
- **opencode** — provider-agnostic terminal coding agent
- **Git**, **Lazygit**
- **Neovim** (LazyVim config in `dotfiles/`)

### Applications

- **Zen Browser** — privacy-focused browser
- **Vesktop** (Discord + Vencord), **Spotify** (via Spicetify, with the Singify karaoke extension)
- **MPV** — media player
- **Plasticity** — CAD
- **Steam** — with Proton
- **Affinity** suite via `affinity-nix`

### System Features

- **PipeWire** — audio server
- **Virtualization** — KVM/QEMU
- **nix-flatpak** — declarative Flatpaks
- **ragenix** — age-encrypted secrets
- **CUPS** — including a Bluetooth label printer with its own backend (`ptouch/`)
- **smartd** — drive health warnings as desktop notifications (amanita)

## Flake Inputs

| Input | Purpose |
| --- | --- |
| `nixpkgs` | NixOS unstable |
| `home-manager` | User environment management |
| `disko` | Declarative disk layout (mycena) |
| `nixos-hardware` | Surface kernel and quirks (mycena) |
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
| `claude-skill-*` | Claude Code skills, pinned as flake inputs |
| `wezterm-image-mcp` | MCP server showing images in a side WezTerm pane (git+ssh) |
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

2. Update hardware configuration (workstations; mycena's layout comes from `disko.nix`):

```bash
nixos-generate-config --show-hardware-config > hosts/<host>/hardware-configuration.nix
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
host keys listed in `secrets/secrets.nix`.

`RULES` must be set: ragenix defaults to `./secrets.nix`, but the manifest lives in `secrets/`.
Pass the identity explicitly with `-i`, using a key whose public half is a recipient in
`secrets/secrets.nix` — a key with a non-default filename is never tried automatically.

```bash
# Edit a secret in place
RULES=secrets/secrets.nix ragenix -e secrets/<name>.age -i <identity>

# Re-key everything after adding a host or key. Rewrites EVERY secret, not just
# the ones whose recipients changed, so expect the whole secrets/ dir to show as
# modified — identical plaintext always re-encrypts to different bytes.
RULES=secrets/secrets.nix ragenix --rekey -i <identity>
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

3. Add the host to `flake.nix`. `modules/core` declares agenix secrets, so the ragenix module is
   required alongside it:

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
    inputs.ragenix.nixosModules.default
  ];
};
```

The `host` argument is what module-level gating keys off, e.g.
`lib.optionals (host == "cordyceps") [ ./laptop-only.nix ]`. A machine that shouldn't carry the
workstation setup can skip `modules/core` entirely, as mycena does.

### Adding New Modules

1. Create a new `.nix` file in `modules/core/` (system) or `modules/home/` (user)
2. Import it in the respective `default.nix`
3. Configure the module with your settings

## Notes

- AMD GPU: Electron and Chromium apps on GFX1201 need explicit GL/ANGLE flags — see the comments
  in `spicetify.nix` and `steam.nix` before changing them
- Hyprland tracks git `main`, which is Lua-only; `hyprctl dispatch` takes Lua, not the legacy
  comma-string form. `hyprctl repl '<code>'` is handy for testing config snippets live
- Only internal drives are mounted at boot; a declared drive that is missing costs a 90 s device
  timeout, so remove its entry when the disk leaves the machine
- The smartd module's `notifications.systembus-notify` option never writes smartd's `-M exec`
  hook on its own, so amanita wires that hook directly
- Host-gated modules: `laptop-only.nix` (cordyceps), `pi-backup.nix` and `udiskie.nix` (amanita),
  plus a few gated lines in `system.nix`, `steam.nix`, `claude.nix` and the keybinds

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Built with the NixOS community's incredible tools and flakes.
