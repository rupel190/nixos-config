{ ... }:
{
  # agenix secrets shared by every host. Kept here rather than under hosts/ so a
  # new machine needs only `git pull` + `nixos-rebuild switch` — the recipient
  # lists in secrets/secrets.nix already govern who can actually decrypt them.
  #
  # NOTE: each referenced .age must exist or the host will not evaluate.

  # Cloudflare Pages deploy token (Pages:Edit) for the recustomize pipeline
  # report. Loaded by that repo's .envrc for wrangler.
  age.secrets.cloudflare-api-token = {
    file = ../../secrets/cloudflare-api-token.age;
    owner = "rupel";
    mode = "0400";
  };

  # claude-sync R2 access keys. modules/home/claude-sync.nix splices these into
  # ~/.claude-sync/config.yaml at activation; the non-secret settings live in
  # that module as plain Nix.
  age.secrets.claude-sync-r2 = {
    file = ../../secrets/claude-sync-r2.age;
    owner = "rupel";
    mode = "0400";
  };

  # age identity that encrypts the synced payload, so R2 only ever holds
  # ciphertext. Its own secret on purpose: agenix lands it here containing just
  # the identity line, which is what age.ParseX25519Identity requires, and
  # /run is tmpfs so it never reaches disk.
  age.secrets.claude-sync-age-key = {
    file = ../../secrets/claude-sync-age-key.age;
    owner = "rupel";
    mode = "0400";
  };
}
