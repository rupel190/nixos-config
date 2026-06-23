let
  amanita-host = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPFcR/wzA+ZsUEnjbRRw3R5avxl9q7EawUHbF3f8vnu3 root@amanita";
  amanita-rupel = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICZWLYjYarb1rjAyhyfMsK1bH/uD7/V2e5rZN4/25xpY rupel@amanita";
in
{
  "my-secret.age".publicKeys = [
    amanita-host
    amanita-rupel
  ];

  # Cloudflare API token (Pages:Edit) for deploying the recustomize pipeline report.
  # host key decrypts at activation; rupel key lets you `ragenix -e` it.
  "cloudflare-api-token.age".publicKeys = [
    amanita-host
    amanita-rupel
  ];
}
