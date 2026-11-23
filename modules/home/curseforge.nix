{ pkgs, ... }:
let
  # CurseForge (system Flatpak from hosts/amanita) without the ad column, which
  # takes 420px of a portrait monitor. /app is read-only, so this copies the
  # deployed app once per Flatpak commit into ~/.cache, swaps in a patched
  # app.asar and runs that copy with `flatpak run --app-path`. A copy, not
  # hardlinks: the files are root's and fs.protected_hardlinks refuses them.
  # Flatpak updates are picked up on the next launch; if the patch stops
  # applying, it says so and starts stock CurseForge.
  launcher = pkgs.writeShellApplication {
    name = "curseforge-noads";
    # flatpak itself comes from services.flatpak on the system PATH
    runtimeInputs = with pkgs; [ coreutils gnugrep python3 libnotify ];
    text = ''
      app=com.overwolf.curseforge
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/curseforge-noads"
      run=(flatpak run --system --branch=stable --arch=x86_64 --command=curseforge)

      prepare() {
        local src commit tmp asar
        src="$(flatpak info --system --show-location "$app")/files" || return 1
        commit="$(flatpak info --system --show-commit "$app")" || return 1
        dst="$cache/$commit"
        [ -e "$dst/.patched" ] && return 0

        # An older copy may still back a running instance; only sweep when it's closed.
        if ! flatpak ps --columns=application | grep -qx "$app"; then
          rm -rf "$cache"
        fi
        mkdir -p "$cache" || return 1
        tmp="$(mktemp -d "$cache/.build.XXXXXX")" || return 1
        cp -a "$src/." "$tmp/" || return 1
        asar="curseforge/resources/app.asar"
        python3 -I ${./curseforge/patch-asar.py} "$src/$asar" "$tmp/$asar" || return 1
        touch "$tmp/.patched" && mv "$tmp" "$dst"
      }

      if prepare; then
        exec "''${run[@]}" --app-path="$dst" "$app" "$@"
      fi
      notify-send -a CurseForge "curseforge-noads" "Ad patch failed to apply; starting stock CurseForge." || true
      exec "''${run[@]}" "$app" "$@"
    '';
  };
in
{
  home.packages = [ launcher ];

  # Same ID as the Flatpak's exported entry, so the menu and its curseforge://
  # and cfauth:// handlers land here. Flatpak's exports come before the profile
  # in XDG_DATA_DIRS, so an xdg.desktopEntries entry would be shadowed.
  home.file.".local/share/applications/com.overwolf.curseforge.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=CurseForge
    GenericName=Mod Manager
    Comment=Discover, install, and manage mods and modpacks for your favorite games
    Exec=${launcher}/bin/curseforge-noads %u
    Icon=com.overwolf.curseforge
    Terminal=false
    Categories=Game;
    Keywords=mods;modpacks;minecraft;curseforge;addons;modding;
    StartupNotify=true
    StartupWMClass=CurseForge
    MimeType=x-scheme-handler/curseforge;x-scheme-handler/cfauth;x-scheme-handler/curseforge-checkout;
  '';
}
