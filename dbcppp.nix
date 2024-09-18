{ src, pkgs, stdenv, cmake, boost, libxml2, libxmlxx, ... }:
stdenv.mkDerivation {
  pname = "dbcppp";
  version = "0.0.1";
  inherit src;
  nativeBuildInputs = [ cmake ];
  propagatedBuildInputs = [ boost libxml2 libxmlxx ];
}
