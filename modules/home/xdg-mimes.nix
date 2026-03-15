{ pkgs, lib, ... }:
with lib;
let
  defaultApps = {
    browser = [ "zen.desktop" ];
    # text = [ "nvim.desktop" ]; # Using nvim from terminal
    image = [ "oculante.desktop" ];
    audio = [ "mpv.desktop" ];
    video = [ "mpv.desktop" ];
    directory = [ "yazi-wezterm.desktop" ]; # Opens yazi in wezterm for "open in explorer" actions
    office = [ "onlyoffice.desktop" ];
    pdf = [ "org.gnome.Evince.desktop" ];
    terminal = [ "org.wezfurlong.wezterm.desktop" ];
    # archive - using terminal tools
    discord = [ "discord.desktop" ];
    bambustudio = [ "com.bambulab.BambuStudio.desktop" ];
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
    bambustudio = [ "x-scheme-handler/bambustudio" ];
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

  # Create yazi-wezterm.desktop for opening directories in yazi via wezterm
  # This is used by apps like Steam when clicking "Browse local files"
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
