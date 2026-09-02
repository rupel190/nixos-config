let
  amanita-host = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPFcR/wzA+ZsUEnjbRRw3R5avxl9q7EawUHbF3f8vnu3 root@amanita";
  amanita-rupel = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICZWLYjYarb1rjAyhyfMsK1bH/uD7/V2e5rZN4/25xpY rupel@amanita";
  # Notebook HOST key — this is what lets agenix decrypt into /run/agenix during
  # activation. The rupel@cordyceps USER key in ~/.ssh is a different thing; it
  # would only let you run `ragenix -e` from the notebook.
  cordyceps-host = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICQ3TrT/nsI5i5o3Tlc+7LUgnShO1OEg3fA7eBiwNgPH root@cordyceps";
in
{
  # Cloudflare API token (Pages:Edit) for deploying the recustomize pipeline report.
  # host key decrypts at activation; rupel key lets you `ragenix -e` it.
  "cloudflare-api-token.age".publicKeys = [
    amanita-host
    amanita-rupel
    cordyceps-host
  ];

  # R2 access keys only — spliced into ~/.claude-sync/config.yaml at activation.
  "claude-sync-r2.age".publicKeys = [
    amanita-host
    amanita-rupel
    cordyceps-host
  ];

  # Payload age identity, kept as its own secret so agenix decrypts it straight
  # to /run/agenix/claude-sync-age-key — a tmpfs path containing only the
  # identity line, which is exactly what age.ParseX25519Identity requires.
  # Bundled with the R2 keys it would have to be extracted to $HOME instead.
  "claude-sync-age-key.age".publicKeys = [
    amanita-host
    amanita-rupel
    cordyceps-host
  ];
}
