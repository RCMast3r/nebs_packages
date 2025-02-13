{ src, pkgs, stdenv, cmake, ... }:
stdenv.mkDerivation {
  pname = "SOEM";
  version = "1.4.0.dev";
  inherit src;
  nativeBuildInputs = [ cmake ];
}