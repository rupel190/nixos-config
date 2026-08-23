{ pkgs, lib, ... }:
with lib;
let
  defaultApps = {
    browser = [ "zen.desktop" ];
    # text = [ "nvim.desktop" ]; # Using nvim from terminal
    image = [ "imv.desktop" ];
    audio = [ "mpv.desktop" ];
    video = [ "mpv.desktop" ];
    directory = [ "yazi-wezterm.desktop" ]; # Opens yazi in wezterm for "open in explorer" actions
    office = [ "onlyoffice.desktop" ];
    pdf = [ "org.gnome.Evince.desktop" ];
    terminal = [ "org.wezfurlong.wezterm.desktop" ];
    # archive - using terminal tools
    discord = [ "discord.desktop" ];
    bambustudio = [ "bambu-studio.desktop" ];
    plasticity = [ "plasticity.desktop" ];
  };

  mimeMap = {
    # text = [ "text/plain" ]; # Using terminal editor
    image = [
      "image/bmp"
      "image/gif"
      "image/jpeg"
      "image/jpg"
      "image/png"
      "image/svg+xml"
      "image/tiff"
      "image/vnd.microsoft.icon"
      "image/webp"
    ];
    audio = [
      "audio/aac"
      "audio/mpeg"
      "audio/ogg"
      "audio/opus"
      "audio/wav"
      "audio/webm"
      "audio/x-matroska"
    ];
    video = [
      "video/mp2t"
      "video/mp4"
      "video/mpeg"
      "video/ogg"
      "video/webm"
      "video/x-flv"
      "video/x-matroska"
      "video/x-msvideo"
    ];
    directory = [ "inode/directory" "x-scheme-handler/file" ]; # For "open in explorer" buttons
    browser = [
      "text/html"
      "x-scheme-handler/about"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
      "x-scheme-handler/unknown"
    ];
    office = [
      "application/vnd.oasis.opendocument.text"
      "application/vnd.oasis.opendocument.spreadsheet"
      "application/vnd.oasis.opendocument.presentation"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      "application/vnd.openxmlformats-officedocument.presentationml.presentation"
      "application/msword"
      "application/vnd.ms-excel"
      "application/vnd.ms-powerpoint"
      "application/rtf"
    ];
    pdf = [ "application/pdf" ];
    terminal = [ "x-scheme-handler/terminal" ];
    # archive = [ # Using terminal tools
    #   "application/zip"
    #   "application/rar"
    #   "application/7z"
    #   "application/*tar"
    # ];
    discord = [ "x-scheme-handler/discord" ];
    bambustudio = [ "x-scheme-handler/bambustudio" "model/3mf" "application/vnd.ms-3mfdocument" "model/stl" ];
    plasticity = [ "application/x-plasticity" "model/step" "application/x-step" ];
  };

  associations =
    with lists;
    listToAttrs (
      flatten (
        mapAttrsToList (
          key: map (type: attrsets.nameValuePair type defaultApps."${key}")
        ) mimeMap
      )
    );
in
{
  # Register model/step MIME type — not in freedesktop shared-mime-info, so .step files
  # are detected as text/plain without this. Globs take priority over magic detection.
  xdg.dataFile."mime/packages/model-step.xml".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
      <mime-type type="model/step">
        <comment>STEP 3D model</comment>
        <glob pattern="*.step"/>
        <glob pattern="*.stp"/>
        <magic priority="50">
          <match type="string" offset="0" value="ISO-10303-21;"/>
        </magic>
      </mime-type>
    </mime-info>
  '';

  # Plasticity's native format — no registered type, so .plasticity files are
  # detected as application/octet-stream. Magic matches the literal header.
  xdg.dataFile."mime/packages/plasticity.xml".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
      <mime-type type="application/x-plasticity">
        <comment>Plasticity 3D model</comment>
        <glob pattern="*.plasticity"/>
        <magic priority="50">
          <match type="string" offset="0" value="plasticity"/>
        </magic>
      </mime-type>
    </mime-info>
  '';

  home.activation.updateMimeDatabase = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.shared-mime-info}/bin/update-mime-database \
      "$HOME/.local/share/mime"
  '';

  xdg.configFile."mimeapps.list".force = true;
  xdg.mimeApps.enable = true;
  xdg.mimeApps.associations.added = associations;
  xdg.mimeApps.defaultApplications = associations;

  home.sessionVariables = {
    # prevent wine from creating file associations
    WINEDLLOVERRIDES = "winemenubuilder.exe=d";
    # Set default browser for apps that don't use xdg-open (like Discord/Electron)
    BROWSER = "zen";
    DEFAULT_BROWSER = "zen";
  };

  # Hide Flatpak's auto-generated desktop entry so only our custom one shows
  home.file.".local/share/applications/com.bambulab.BambuStudio.desktop".text = ''
    [Desktop Entry]
    NoDisplay=true
  '';

  # Hide umpv — single-instance mpv wrapper, redundant alongside mpv.desktop
  home.file.".local/share/applications/umpv.desktop".text = ''
    [Desktop Entry]
    NoDisplay=true
  '';

  # Create yazi-wezterm.desktop for opening directories in yazi via wezterm
  # This is used by apps like Steam when clicking "Browse local files"
  # Bambu Studio via Flatpak. Two NixOS/GFX1201 workarounds, both baked into every launcher
  # (this desktop entry, the fish alias, the yazi opener):
  #
  # 1. WEBKIT_DISABLE_DMABUF_RENDERER=1 — the embedded WebKitGTK view (MakerWorld deep-links,
  #    login/home panel) SIGSEGVs via its DMABUF/GL renderer on RDNA4; the SHM path avoids it.
  #    (The old VK_ICD_FILENAMES=/run/opengl-driver injection was a no-op — Flatpak mounts
  #    neither /run/opengl-driver nor /nix/store — and the runtime's own RADV supports RDNA4.)
  #
  # 2. env PATH=/usr/bin:... — since the GNOME 50 runtime (Bambu 2.7.x) GTK loads icons via
  #    glycin, which runs its SVG loader in a NESTED `flatpak-spawn --sandbox` wrapped in
  #    `prlimit`. That sub-sandbox inherits the LAUNCHER's PATH, and on NixOS there is no
  #    /usr/bin in PATH → `prlimit` isn't found → loader dies → GTK "Bail out!" on the first
  #    SVG icon = instant crash. /usr/bin exists INSIDE the runtime, so naming it on PATH is
  #    enough; /run/current-system/sw/bin is kept so `flatpak` itself resolves.
  xdg.desktopEntries.bambu-studio = {
    name = "Bambu Studio";
    genericName = "3D Printer Slicer";
    icon = "com.bambulab.BambuStudio";
    comment = "Bambu Lab slicer";
    exec = "env PATH=/usr/bin:/run/current-system/sw/bin flatpak run --env=WEBKIT_DISABLE_DMABUF_RENDERER=1 com.bambulab.BambuStudio %u";
    terminal = false;
    type = "Application";
    categories = [ "Graphics" "3DGraphics" ];
    mimeType = [ "x-scheme-handler/bambustudio" "model/3mf" "model/stl" ];
  };


  xdg.desktopEntries.yazi-wezterm = {
    name = "Yazi (File Manager)";
    genericName = "File Manager";
    icon = "yazi";
    comment = "Terminal file manager in WezTerm";
    exec = "wezterm start -- yazi %u";
    terminal = false;
    type = "Application";
    categories = [ "Utility" "Core" "System" "FileTools" "FileManager" ];
    mimeType = [ "inode/directory" "x-scheme-handler/file" ];
  };
}
