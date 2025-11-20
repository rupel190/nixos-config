{ pkgs, ... }:
{
  programs.lazygit = {
    enable = true;
    # TODO: integrate with nvim lazygit.nvim plugin -> If necessary!
  };
}
