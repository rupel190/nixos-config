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
    plasticity = [ "Plasticity.desktop" ];
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
    bambustudio = [ "x-scheme-handler/bambustudio" "model/3mf" "application/vnd.ms-3mfdocument" ];
    plasticity = [ "model/step" "application/x-step" ];
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
  # Bambu Studio via Flatpak with RDNA 4 Vulkan ICD fix
  xdg.desktopEntries.bambu-studio = {
    name = "Bambu Studio";
    genericName = "3D Printer Slicer";
    icon = "com.bambulab.BambuStudio";
    comment = "Bambu Lab slicer";
    exec = "flatpak run --env=VK_ICD_FILENAMES=/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json com.bambulab.BambuStudio %u";
    terminal = false;
    type = "Application";
    categories = [ "Graphics" "3DGraphics" ];
    mimeType = [ "x-scheme-handler/bambustudio" "model/3mf" ];
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
