{
  config,
  pkgs,
  lib,
  host,
  inputs,
  ...
}:
{
  # opencode 2.0 dropped its CLAUDE.md fallback; live link so claude-sync edits apply to both.
  xdg.configFile."opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/CLAUDE.md";

  # opencode — provider-agnostic terminal coding agent (sst/opencode).
  programs.opencode = {
    enable = true;
    package = inputs.nixpkgs-opencode.legacyPackages.${pkgs.stdenv.hostPlatform.system}.opencode;

    settings = {
      # Self-update would try to replace a read-only store binary; the flake pins it.
      autoupdate = false;

      # opencode otherwise downloads prebuilt LSP servers, which don't run on NixOS.
      lsp.nix = {
        command = [ "${pkgs.nixd}/bin/nixd" ];
        extensions = [ ".nix" ];
      };
    }
    # Only amanita runs Ollama (hosts/amanita). Models are auto-discovered; these entries
    # cap the context opencode plans for at the server's OLLAMA_CONTEXT_LENGTH instead of
    # the model's advertised 256K, and keep the output reservation from eating it.
    // lib.optionalAttrs (host == "amanita") {
      providers.ollama = {
        settings.baseURL = "http://127.0.0.1:11434/v1";
        models = {
          "qwen3.5:9b".limit = {
            context = 32768;
            output = 8192;
          };
          "flint:40b-a2b".limit = {
            context = 32768;
            output = 8192;
          };
        };
      };
    };

    # No tui.theme here on purpose: opencode 2 keeps the theme ("system", reusing the
    # WezTerm palette) in the writable ~/.config/opencode/cli.json. A generated tui.json
    # is a read-only, hard-linked store file, and `herdr integration install opencode`
    # refuses to edit it ("config has multiple hard links").
  };
}
