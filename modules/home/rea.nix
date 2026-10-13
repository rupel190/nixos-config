{ pkgs, lib, ... }:
let
  # REA (github.com/morluto/rea) drives an analysis toolchain rather than
  # bundling one: it reads GHIDRA_INSTALL_DIR and JAVA_HOME from the
  # environment and shells out to providers on PATH. Its `setup` otherwise
  # installs distro packages (.deb/.rpm/pacman), which is the one part that
  # cannot work here -- so everything comes from nixpkgs instead.
  jdk = pkgs.jdk21; # Ghidra 12.1.x requires JDK 21+
  node = pkgs.nodejs_24; # REA engines: ^22.19 || ^24.11 || >=26

  # nixpkgs installs Ghidra under $out/lib/ghidra (pkgs/tools/security/ghidra,
  # pkg_path), and REA needs the native decompiler beneath it at
  # Ghidra/Features/Decompiler/os/linux_x86_64/decompile -- present in 12.1.2.
  ghidraHome = "${pkgs.ghidra}/lib/ghidra";

  # Providers REA invokes by name when a target calls for them.
  providers = with pkgs; [
    binwalk # firmware carving
    unblob # firmware extraction
    jadx # Android/dex -> Java
    radare2 # native fallback disassembly
    android-tools # adb, for on-device analysis
    python3 # required by the Linux demo/observation paths
    xorg.xorgserver # Xvfb, same
    file
  ];
in
{
  home.packages = [
    # Ghidra is already in the wrapper's closure, so exposing the GUI and
    # ghidra-analyzeHeadless on PATH costs no extra disk.
    pkgs.ghidra

    (pkgs.writeShellScriptBin "rea" ''
      export GHIDRA_INSTALL_DIR=${lib.escapeShellArg ghidraHome}
      export JAVA_HOME=${lib.escapeShellArg jdk.home}
      export PATH=${lib.makeBinPath ([ node jdk ] ++ providers)}:"$PATH"
      # Fetched by npx rather than packaged: the repo is a turborepo with five
      # git submodules, so a derivation would fight the tool's own updates.
      #
      # Pinned, not `latest`, because `rea setup` writes MCP registrations
      # pinned to whichever version performed setup -- a floating CLI would
      # drift away from the servers it registered. Bump deliberately, then
      # re-run `rea setup`. Override ad hoc with REA_VERSION=x.y.z rea ...
      exec ${node}/bin/npx --yes "rea-agents@''${REA_VERSION:-6.4.0}" "$@"
    '')
  ];
}
