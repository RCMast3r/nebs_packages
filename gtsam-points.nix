{ src, pkgs, stdenv, cmake, gtsam, ... }:
stdenv.mkDerivation {
  pname = "gtsam-points";
  version = "v1.0.7-dev";
  inherit src;
  propagatedBuildInputs = [ gtsam ] ++ [ pkgs.boost pkgs.eigen pkgs.nanoflann pkgs.tbb ];
  nativeBuildInputs = [ cmake ];
}