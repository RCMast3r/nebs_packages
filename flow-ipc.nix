{ src, pkgs, stdenv, boost184, capnproto, jemalloc, fmt, cmake, ... }:
stdenv.mkDerivation {
  pname = "flow-ipc";
  version = "1.0.2.b";
  inherit src;
  nativeBuildInputs = [ cmake ];
  buildInputs = [ boost184 capnproto jemalloc fmt ];
}