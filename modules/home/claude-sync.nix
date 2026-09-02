{ pkgs, config, lib, ... }:
let
  # Not in nixpkgs. Upstream ships a Go binary via npm; buildGoModule skips that
  # wrapper entirely. `claude-sync update` self-updates in place and therefore
  # cannot work on NixOS — bump `version` + hashes here instead.
  claude-sync = pkgs.buildGoModule rec {
    pname = "claude-sync";
    version = "1.17.1";

    src = pkgs.fetchFromGitHub {
      owner = "tawanorg";
      repo = "claude-sync";
      rev = "v${version}";
      hash = "sha256-hsIski28Dr3k3+/0/+k6XySAeoQ6e5nTeLAGRtZ2kAQ=";
    };

    vendorHash = "sha256-VLqVk5bhM+WoEbP+agFpm1LjzI2qFWlWQZB8yV2vbOU=";
    subPackages = [ "cmd/claude-sync" ];

    # Matches upstream's Makefile; without this `--version` reports "dev".
    ldflags = [ "-s" "-w" "-X" "main.version=${version}" ];

    meta = with lib; {
      description = "Sync ~/.claude across devices via age-encrypted cloud storage";
      homepage = "https://github.com/tawanorg/claude-sync";
      license = licenses.mit;
      mainProgram = "claude-sync";
    };
  };

  # This repo is PUBLIC, so account_id and endpoint live in the secret alongside
  # the keys rather than here — they identify the Cloudflare account, and a
  # public commit is permanent. Only provider and bucket, which identify
  # nothing, stay in the clear.
  storageHead = pkgs.writeText "claude-sync-storage-head" ''
    storage:
      provider: r2
      bucket: claude-sync
  '';

  configBody = pkgs.writeText "claude-sync-config-body" ''

    # Payload encryption key: what makes R2 hold ciphertext only. Its own agenix
    # secret, so this tmpfs path holds just the identity line and the key never
    # reaches disk. No `claude-sync init` and no passphrase; cordyceps decrypts
    # the identical key with its own host key.
    encryption_key_path: /run/agenix/claude-sync-age-key

    scope: full

    # Full scope minus `plugins` (regenerable marketplace cache, 2.9M, incl. 56
    # PID-named .in_use lockfiles; only the 3.2K installed_plugins.json is real
    # state). `hooks` is not a claude-sync built-in path, but settings.json
    # references ~/.claude/hooks/{notify,wezterm-status}.sh by absolute path and
    # those are hand-written plain files — they must travel together.
    # settings.local.json is omitted deliberately: per-machine by definition.
    sync_paths:
      - CLAUDE.md
      - settings.json
      - hooks
      - skills
      - projects
      - tasks
      - history.jsonl

    exclude:
      # Both of these are git repos that travel via git, not via claude-sync.
      # interaction-tests is a symlink into ~/projects; beamng-vehicle-values is
      # a real checkout of github.com/rupel190/beamng-vehicle-values (260K of
      # .git wrapping 52K of content). Syncing either would put a divergent,
      # remote-less copy on the other machine. Clone them there instead.
      - skills/interaction-tests
      - skills/beamng-vehicle-values
      # Safety net: any skill that later becomes a repo should not drag .git
      # internals across. doublestar syntax, matched against the relative path.
      - "**/.git/**"

    # ~/.claude.json is rewritten per machine by home.activation.termImageMcp and
    # its term-image entry embeds absolute /nix/store paths. Never sync it.
    mcp_sync: false
  '';
in
{
  home.packages = [ claude-sync ];

  # config.yaml is assembled from two sources so that non-secret settings stay
  # visible in this file rather than being buried inside an encrypted blob:
  # the plain fragments above, plus /run/agenix/claude-sync-r2 which holds ONLY
  # `access_key_id:` and `secret_access_key:`. They get indented two spaces to
  # nest under `storage:`.
  #
  # Written rather than symlinked because claude-sync's own `paths`/`mcp`
  # subcommands rewrite config.yaml; a store symlink would make them fail. The
  # result is 0600 in $HOME — same exposure as `claude-sync init` would produce.
  # /run/agenix/claude-sync-r2 holds the four `storage:` fields that must not be
  # public: account_id, endpoint, access_key_id, secret_access_key. Every line is
  # indented two spaces and spliced under `storage:` between the fragments above.
  # Everything else — scope, sync_paths, exclude, mcp_sync — stays reviewable
  # here in plain Nix rather than inside an encrypted blob.
  #
  # The payload key is deliberately NOT here — as its own secret it is read
  # straight from /run/agenix, never written out.
  home.activation.claudeSyncConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    secret=/run/agenix/claude-sync-r2
    out="$HOME/.claude-sync/config.yaml"
    if [ -r "$secret" ]; then
      $DRY_RUN_CMD mkdir -p "$HOME/.claude-sync"
      $DRY_RUN_CMD sh -c "
        umask 077
        { cat ${storageHead}; sed 's/^/  /' $secret; cat ${configBody}; } > $out.tmp
        mv $out.tmp $out
      "
    else
      echo "claude-sync: /run/agenix/claude-sync-r2 not readable; config.yaml not written"
    fi
  '';
}
