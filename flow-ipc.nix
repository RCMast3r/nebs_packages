{ src, pkgs, stdenv, boost184, capnproto, jemalloc, fmt, cmake, pkg-config, ... }:
stdenv.mkDerivation {
  pname = "flow-ipc";
  version = "1.0.2.b";
  inherit src;
  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [ boost184 capnproto jemalloc fmt pkg-config ];
}