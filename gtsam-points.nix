{ src, pkgs, stdenv, cmake, gtsam_pkg, ... }:
stdenv.mkDerivation {
  pname = "gtsam-points";
  version = "v1.0.7-dev";
  inherit src;
  propagatedBuildInputs = [ gtsam_pkg ] ++ [ pkgs.boost pkgs.eigen pkgs.nanoflann pkgs.tbb ];
  nativeBuildInputs = [ cmake ];
}