{ src, pkgs, stdenv, cmake, gtsam-points, ... }:
stdenv.mkDerivation {
  pname = "glim";
  version = "1.0.7-dev";
  inherit src;
  propagatedBuildInputs = with pkgs; [ boost eigen nanoflann opencv gtsam-points spdlog ];
  nativeBuildInputs = [ cmake ];
  cmakeFlags = ["-DBUILD_WITH_CUDA=OFF" "-DBUILD_WITH_VIEWER=OFF"];
}