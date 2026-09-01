{
  lib,
  pkgs,
  inputs,
  username,
  ...
}:
let
  # Models live off the Nix store: 20 GB blobs, replaced by hand, no hash worth
  # pinning. nvme950 has the space (/ is at 82%) and is the fastest free disk.
  dataDir = "/mnt/nvme950/comfyui";

  # rocmSupport in its own nixpkgs instance so the flag can't rebuild the rest of
  # the system. Hydra already built this exact torch — the closure is a download.
  pkgsRocm = import inputs.nixpkgs {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = {
      allowUnfree = true;
      rocmSupport = true;
    };
  };

  # repo | subdir | file — one row per weight, fetched on demand, never hashed.
  # fp8 over GGUF deliberately: gfx1201 does FP8 in hardware (measured 175 vs
  # 92 TFLOP/s bf16), and GGUF dequantises to bf16 to compute. The 20 GB model
  # overflows 16 GB VRAM, but spill runs at 48 GB/s over PCIe 5.0 — far cheaper
  # than halving the matmul rate.
  modelManifest = [
    "Comfy-Org/Qwen-Image-Edit_ComfyUI|diffusion_models|split_files/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors"
    "Comfy-Org/Qwen-Image_ComfyUI|text_encoders|split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"
    "Comfy-Org/Qwen-Image_ComfyUI|vae|split_files/vae/qwen_image_vae.safetensors"
    "lightx2v/Qwen-Image-Edit-2511-Lightning|loras|Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors"
  ];

  comfy-models = pkgs.writeShellApplication {
    name = "comfy-models";
    runtimeInputs = [ pkgs.aria2 ];
    text = ''
      dest="${dataDir}/models"
      for row in ${lib.escapeShellArgs modelManifest}; do
        repo="''${row%%|*}"; rest="''${row#*|}"
        sub="''${rest%%|*}"; path="''${rest#*|}"
        file="''${path##*/}"
        if [[ -s "$dest/$sub/$file" ]]; then
          echo "have  $sub/$file"; continue
        fi
        echo "fetch $sub/$file  <- $repo"
        mkdir -p "$dest/$sub"
        # -x16: HF throttles single connections hard; these are 20 GB files.
        aria2c -x16 -s16 -k16M --continue=true --auto-file-renaming=false \
          -d "$dest/$sub" -o "$file" \
          "https://huggingface.co/$repo/resolve/main/$path"
      done
      echo "models in $dest:"; du -sh "$dest"/* 2>/dev/null || true
    '';
  };

  # Headless driver for the edit loop: same graph, new image/prompt/seed each call.
  comfy-edit = pkgs.writers.writePython3Bin "comfy-edit" {
    flakeIgnore = [
      "E501"
      "E402"
    ];
  } (builtins.readFile ./comfy-edit.py);
in
{
  services.comfyui = {
    enable = true;
    package = pkgsRocm.comfyui;
    inherit dataDir;
    extraArgs = [
      "--disable-auto-launch" # it's a service; there is no browser to launch
      "--preview-method=auto" # watch the latent resolve — the point of an edit loop
      # 1.0 starved the compositor into a session crash: the desktop alone
      # measures 3.5 GB idle, and torch's caching allocator overshoots this
      # budget anyway (15.4 GB reserved vs a 13.2 GB "usable" figure).
      "--reserve-vram=4.0"
    ];
  };

  environment.systemPackages = [
    comfy-models
    comfy-edit
  ];

  # Shared with the desktop user: drop photos in input/, pull results from output/.
  users.users.${username}.extraGroups = [ "comfyui" ];
  systemd.tmpfiles.settings."10-comfyui".${dataDir}.d.mode = lib.mkForce "0770";

  systemd.services.comfyui = {
    serviceConfig.UMask = "0007"; # keep group-write on everything it creates

    # ProtectHome=tmpfs means $HOME is thrown away on restart; park every compiler
    # cache on the data dir so MIOpen/Triton kernels survive.
    environment = {
      HOME = dataDir;
      MIOPEN_USER_DB_PATH = "${dataDir}/.cache/miopen";
      MIOPEN_CUSTOM_CACHE_DIR = "${dataDir}/.cache/miopen";
      TRITON_CACHE_DIR = "${dataDir}/.cache/triton";
      TORCHINDUCTOR_CACHE_DIR = "${dataDir}/.cache/torchinductor";
      # Let the allocator grow/shrink segments instead of hoarding fragmented
      # ones; HIP is the ROCm name, PYTORCH_CUDA_ALLOC_CONF is its alias.
      PYTORCH_HIP_ALLOC_CONF = "expandable_segments:True";
      # No HSA_OVERRIDE_GFX_VERSION: ROCm 7.2 targets gfx1201 natively, and
      # overriding it on a supported card silently picks the wrong kernels.
    };

    preStart = lib.mkAfter "mkdir -p ${dataDir}/.cache";
  };
}
