{ src, pkgs, stdenv, cmake, lz4, zstd, pkg-config, ... }:
stdenv.mkDerivation {
  pname = "mcap";
  version = "0.0.1";
  inherit src;
  propagatedBuildInputs = [lz4 zstd ];
  propagatedNativeBuildInputs = [cmake pkg-config ];
}