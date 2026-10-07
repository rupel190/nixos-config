{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  patchelf,
  makeWrapper,
  libsecret,
  glib,
}:
# Official Proton Drive CLI (ProtonDriveApps/sdk), a Bun --compile binary.
# Only the interpreter is patched: strip or an rpath rewrite would damage the appended JS payload.
stdenvNoCC.mkDerivation rec {
  pname = "proton-drive";
  version = "0.9.0";
  src = fetchurl {
    url = "https://proton.me/download/drive/cli/${version}/linux-x64/proton-drive";
    hash = "sha512-NTMCW6aa4RK2Tj4B+8wa0GiBNqQEP2z2pyiGln2F/c2ewjVHnC4RMXFhS+UiW/upNCdQmgXKWqYHHZJPp+kcqA==";
  };
  dontUnpack = true;
  dontStrip = true;
  nativeBuildInputs = [
    patchelf
    makeWrapper
  ];
  installPhase = ''
    install -Dm755 $src $out/libexec/proton-drive
    patchelf --set-interpreter "$(cat ${stdenv.cc}/nix-support/dynamic-linker)" $out/libexec/proton-drive
    # libsecret is dlopen'd for the keychain credential store
    makeWrapper $out/libexec/proton-drive $out/bin/proton-drive \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libsecret glib ]}
  '';
  meta.mainProgram = "proton-drive";
}
