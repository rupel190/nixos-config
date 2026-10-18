{ pkgs, lib, ... }:
let
  # FLUX.1 Kontext [dev] image editing on ROCm. NON-COMMERCIAL licence (FLUX.1 [dev] NC).
  # nixpkgs torchWithRocm isn't in the binary cache, so torch comes from PyTorch's ROCm wheels in a venv.
  home = "/mnt/nvme950/ai/flux-kontext";
  python = pkgs.python313;

  # Libraries the manylinux ROCm wheels expect from the host (ROCm, libdrm, numa ship inside them).
  libPath = lib.makeLibraryPath [
    pkgs.stdenv.cc.cc.lib
    pkgs.zlib
    pkgs.bzip2
    pkgs.xz
    pkgs.zstd
  ];

  env = ''
    export FLUX_KONTEXT_HOME="''${FLUX_KONTEXT_HOME:-${home}}"
    export LD_LIBRARY_PATH="${libPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1
    export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
  '';

  flux-kontext = pkgs.writeShellApplication {
    name = "flux-kontext";
    text = env + ''
      export HF_HUB_OFFLINE=1
      exec "$FLUX_KONTEXT_HOME/venv/bin/python" ${./flux-kontext/flux-kontext.py} "$@"
    '';
  };

  flux-kontext-setup = pkgs.writeShellApplication {
    name = "flux-kontext-setup";
    runtimeInputs = [ pkgs.uv pkgs.aria2 ];
    text = env + ''
      export UV_CACHE_DIR="$FLUX_KONTEXT_HOME/../uv-cache"
      export FLUX_PYTHON=${python}/bin/python3.13
      export FLUX_REQUIREMENTS=${./flux-kontext/requirements.txt}
      bash ${./flux-kontext/setup.sh}
    '';
  };
in
{
  home.packages = [ flux-kontext flux-kontext-setup ];
}
