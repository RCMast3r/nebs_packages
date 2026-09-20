{ lib
, stdenv
, cmake
, foxglove-sdk-cpp
}:

# End to end check: a downstream CMake project that consumes the SDK purely
# through `find_package(foxglove-sdk)`, exactly as an external user would. It
# links both the static and the shared flavour and runs them, so a broken
# exported target, a missing transitive platform link library or a bad RPATH
# fails the build rather than surfacing in someone else's project.
stdenv.mkDerivation {
  pname = "foxglove-sdk-cpp-consumer";
  version = "0.1.0";
  src = ./.;

  strictDeps = true;
  nativeBuildInputs = [ cmake ];
  buildInputs = [ foxglove-sdk-cpp ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ctest --output-on-failure
    runHook postCheck
  '';

  meta = {
    description = "find_package round trip test for the Foxglove C++ SDK package";
    platforms = lib.platforms.unix;
  };
}
