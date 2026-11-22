{ config, ... }:
let
  pi = "10.0.0.10";
in
{
  # paperless-gpt on the Pi asks this Ollama: qwen3.5:9b reads the page images (OCR) and suggests
  # titles, tags, senders and dates. While amanita is off, documents simply wait for it.
  services.ollama.host = "0.0.0.0";
  # Ollama has no login: only the Pi gets in, the default-deny firewall keeps everyone else out
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p tcp -s ${pi} --dport ${toString config.services.ollama.port} -j nixos-fw-accept
  '';
}
