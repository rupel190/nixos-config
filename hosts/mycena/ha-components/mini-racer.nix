# V8 for Python, a hard dependency of dreame-vacuum (dreame/map.py imports it
# at top level to run the vendor's map-optimiser JS). Not in nixpkgs.
#
# Packaged from the upstream wheel, NOT the sdist: the sdist builds V8 from
# source, which is hours on amanita and impossible on the Surface. The wheel is
# py3-none — the engine is a plain libmini_racer.so loaded through ctypes, not a
# CPython extension — so it works on whatever Python HA is built with. The .so
# links only glibc and libgcc_s, so autoPatchelf has almost nothing to do.
{
  lib,
  stdenv,
  buildPythonPackage,
  fetchPypi,
  autoPatchelfHook,
}:

buildPythonPackage rec {
  pname = "mini-racer";
  version = "0.14.1";
  format = "wheel";

  src = fetchPypi {
    pname = "mini_racer";
    inherit version format;
    dist = "py3";
    python = "py3";
    abi = "none";
    platform = "manylinux_2_27_x86_64";
    hash = "sha256-zfOgiOE2PxamlSiPiCq/drNwW44d8hQYIIuH7QEAN6Q=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ]; # libgcc_s.so.1

  pythonImportsCheck = [ "py_mini_racer" ];

  meta = {
    description = "Minimal, modern embedded V8 for Python";
    homepage = "https://github.com/bpcreech/PyMiniRacer";
    license = lib.licenses.isc;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
