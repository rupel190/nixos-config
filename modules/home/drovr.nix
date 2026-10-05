# drovr (github.com/rupel190/drovr): headless Claude Code workers on cheaper backends.
# The module lives in that repo; this file is the personal half: key, providers, allowlist.
{ pkgs, inputs, ... }:
{
  imports = [ inputs.drovr.homeManagerModules.default ];

  programs.drovr = {
    enable = true;
    claudePackage = inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default;

    # DeepSeek maps claude-opus to v4-pro and haiku/sonnet to flash on its side,
    # so background calls need no smallModel. Key: modules/core/secrets.nix (amanita only).
    providers.deepseek = {
      baseUrl = "https://api.deepseek.com/anthropic";
      model = "deepseek-v4-pro";
      keyFile = "/run/agenix/deepseek-api-key";
    };

    # Private repos only, on request; public repos qualify without being listed.
    allowedRepos = [ ];

    # Status-bar summary; wezterm.nix shows it in the tabline.
    weztermHelper = true;
  };
}
