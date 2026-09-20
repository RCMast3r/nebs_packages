{ src, pkgs, stdenv, cmake, gtsam-points, boost186, fmt_10, ... }:
stdenv.mkDerivation {
  pname = "glim";
  version = "1.0.7-dev";
  inherit src;
  # Same boost as gtsam/gtsam-points.
  # glim logs shared_ptrs through spdlog. fmt 11 dropped the implicit
  # pointer-like formatter that relies on, so pin spdlog to fmt 10 and make
  # sure glim itself compiles against the same headers.
  propagatedBuildInputs = [ boost186 gtsam-points fmt_10 (pkgs.spdlog.override { fmt = fmt_10; }) ]
    ++ (with pkgs; [ eigen nanoflann opencv ]);
  nativeBuildInputs = [ cmake ];
  cmakeFlags = ["-DBUILD_WITH_CUDA=OFF" "-DBUILD_WITH_VIEWER=OFF" "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"];
}