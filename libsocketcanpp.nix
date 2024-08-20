{ src, pkgs, stdenv, cmake, ... }:
stdenv.mkDerivation {
  pname = "libscocketcanpp";
  version = "0.0.1";
  inherit src;
  nativeBuildInputs = [ cmake ];
}