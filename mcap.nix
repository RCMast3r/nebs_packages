{ src, pkgs, stdenv, cmake, lz4, zstd, pkg-config, ... }:
stdenv.mkDerivation {
  pname = "mcap";
  version = "0.0.1";
  inherit src;
  cmakeFlags = [ "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" ];
  propagatedBuildInputs = [ lz4 zstd ];
  buildInputs = [ lz4 zstd ];
  propagatedNativeBuildInputs = [cmake pkg-config ];
}