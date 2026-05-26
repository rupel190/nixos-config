{ pkgs, ... }:

let
  grayjay-src = pkgs.fetchzip {
    url = "https://updater.grayjay.app/Apps/Grayjay.Desktop/Grayjay.Desktop-linux-x64.zip";
    hash = "sha256-6bnAibjbWBZtBXRSGdmSoGNffaEsYlXDr4vvjqgUSl8=";
  };

  desktopItem = pkgs.makeDesktopItem {
    name = "grayjay";
    desktopName = "Grayjay";
    exec = "grayjay %u";
    comment = "Watch your creators";
    categories = [ "AudioVideo" "Video" "Network" ];
    mimeTypes = [ "x-scheme-handler/grayjay" ];
  };

  grayjay = pkgs.buildFHSEnv {
    name = "grayjay";
    targetPkgs = _: with pkgs; [
      libz
      icu
      libgbm
      openssl # for updater

      libx11
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxcb

      gtk3
      glib
      nss
      nspr
      dbus
      atk
      cups
      libdrm
      expat
      libxkbcommon
      pango
      cairo
      udev
      alsa-lib
      mesa
      libGL
      libsecret
    ];
    runScript = pkgs.writeShellScript "grayjay-launch" ''
      CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/grayjay"
      VERSION_FILE="$CACHE/.nix-store-version"
      STORE="${grayjay-src}"

      # Re-stage app whenever the Nix derivation changes (e.g. after upgrade)
      if [ ! -f "$VERSION_FILE" ] || [ "$(cat "$VERSION_FILE")" != "$STORE" ]; then
        echo "Staging Grayjay to writable cache..."
        rm -rf "$CACHE"
        cp -r "$STORE/." "$CACHE"
        chmod -R u+w "$CACHE"
        printf '%s' "$STORE" > "$VERSION_FILE"
      fi

      cd "$CACHE"
      exec "$CACHE/Grayjay" --no-sandbox "$@"
    '';
    extraInstallCommands = ''
      install -Dm644 ${desktopItem}/share/applications/grayjay.desktop \
        $out/share/applications/grayjay.desktop
    '';
  };
in
{
  home.packages = [ grayjay ];
}
