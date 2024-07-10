{ src, pkgs, stdenv, cmake, ... }:
stdenv.mkDerivation {
  pname = "comms";
  version = "0.0.1";
  inherit src;
  nativeBuildInputs = [ cmake ];
  # buildInputs = [ libxml2 ];
}