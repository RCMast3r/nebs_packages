{ src, pkgs, stdenv, cmake, boost186, ... }:
stdenv.mkDerivation {
  pname = "gtsam";
  version = "4.2.0-dev";
  inherit src;
  # gtsam 4.2.0 asks find_package(Boost COMPONENTS system ...); Boost 1.89
  # dropped the compatibility `system` component, so pin the newest boost that
  # still exports it. gtsam-points and glim must use the same one.
  propagatedBuildInputs = [ boost186 pkgs.eigen ];
  nativeBuildInputs = [ cmake ];
  # gtsam 4.2.0 declares cmake_minimum_required(VERSION 3.0); CMake 4 refuses
  # anything below 3.5 outright.
  cmakeFlags = ["-DGTSAM_USE_SYSTEM_EIGEN=ON" "-DGTSAM_WITH_TBB=OFF" "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"];
}