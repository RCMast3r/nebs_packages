{ src, pkgs, stdenv, boost186, capnproto, jemalloc, fmt_10, cmake, pkg-config, ... }:
stdenv.mkDerivation {
  pname = "flow-ipc";
  version = "1.0.2.b";
  inherit src;
  nativeBuildInputs = [ cmake pkg-config ];
  # flow-ipc 1.0.2 uses fmt::localtime, which fmt 11 removed; fmt 10 is the
  # newest release that still provides it.
  buildInputs = [ boost186 capnproto jemalloc fmt_10 pkg-config ];
}