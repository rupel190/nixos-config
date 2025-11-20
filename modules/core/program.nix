{ pkgs, lib, ... }:
{
  programs.dconf.enable = true;

  # TODO: Enable if necessary
  # programs.dconf.profiles.user.databases = [
  #   {
  #     settings."org/gnome/desktop/interface" = {
  #       gtk-theme = "Adwaita";
  #       icon-theme = "Flat-Remix-Red-Dark";
  #       font-name = "Noto Sans Medium 11";
  #       document-font-name = "Noto Sans Medium 11";
  #       monospace-font-name = "Noto Sans Mono Medium 11";
  #     };
  #   }
  # ];

  programs.yazi.enable = true;
  programs.fish.enable = true;

  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  #   # pinentryFlavor = "";
  # };

  # TODO: Allows applications to refer to linux default paths -
  # mason nvim plugin would need that, but maybe keep it working without
  # programs.nix-ld.enable = true;
  # programs.nix-ld.libraries = with pkgs; [ ];
}
