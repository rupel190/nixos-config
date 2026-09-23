{ ... }:
{
  # Automount sticks and SATA-adapter drives at /run/media/rupel/<label>, owned by you
  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "auto"; # icon only while a removable drive is present; its menu unmounts / powers off
  };

  # --appindicator: SNI icon for the AGS tray; udiskie's default XEmbed icon can't show on Wayland
  xsession.preferStatusNotifierItems = true;
}
