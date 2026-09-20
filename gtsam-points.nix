{ src, pkgs, stdenv, cmake, gtsam_pkg, boost186, ... }:
stdenv.mkDerivation {
  pname = "gtsam-points";
  version = "v1.0.7-dev";
  inherit src;
  # Same boost as gtsam: mixing two boosts in one link would be an ODR hazard.
  propagatedBuildInputs = [ gtsam_pkg ] ++ [ boost186 pkgs.eigen pkgs.nanoflann pkgs.tbb ];
  cmakeFlags = [ "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" ];
  nativeBuildInputs = [ cmake ];
}