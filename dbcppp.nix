{ src, pkgs, stdenv, cmake, boost, libxml2, libxmlxx, ... }:
stdenv.mkDerivation {
  pname = "dbcppp";
  version = "0.0.1";
  inherit src;
  nativeBuildInputs = [ cmake ];
  propagatedBuildInputs = [ boost libxml2 libxmlxx ];
  # dbcppp uses uint64_t without including <cstdint>, which GCC 13 stopped
  # providing transitively.
  # CXXFLAGS rather than NIX_CFLAGS_COMPILE: the latter also hits the C
  # compiler, and <cstdint> is C++ only, which breaks CMake's C compiler probe.
  env.CXXFLAGS = "-include cstdint";
  cmakeFlags = [ "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" ];
}
