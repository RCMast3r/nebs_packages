{ src, pkgs, stdenv, cmake, ... }:
stdenv.mkDerivation {
  pname = "gtsam";
  version = "4.2.0-dev";
  inherit src;
  propagatedBuildInputs = with pkgs; [ boost eigen ];
  nativeBuildInputs = [ cmake ];
  cmakeFlags = ["-DGTSAM_USE_SYSTEM_EIGEN=ON" "-DGTSAM_WITH_TBB=OFF"];
}