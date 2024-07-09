{ src, pkgs, stdenv, cmake, libxml2, ... }:
stdenv.mkDerivation {
  pname = "commsdsl";
  version = "6-something";
  inherit src;
  nativeBuildInputs = [ cmake ];
  buildInputs = [ libxml2 ];
}