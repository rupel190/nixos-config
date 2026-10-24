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
      # Peak USD per 1M tokens (off-peak is half), so drovr list shows an upper bound.
      price = {
        input = 1.32;
        cachedInput = 0.044;
        output = 3.96;
      };
      effort = "medium";
      # The cheap tier, for mechanical edits: `drovr run --model deepseek-flash`.
      models.deepseek-flash = {
        price = {
          input = 0.3;
          cachedInput = 0.006;
          output = 1.2;
        };
        effort = "low";
      };
    };

    # Per day, all workers, in USD like the prices: ≈ €2 warns, ≈ €5 refuses new calls
    # (a running one finishes). No hard dailyBudget.
    dailyWarn = 2.3;
    dailySoftLimit = 5.8;

    # Private repos only, on request; public repos qualify without being listed.
    allowedRepos = [ ];

    # Status-bar summary; wezterm.nix shows it in the tabline.
    weztermHelper = true;
  };
}
