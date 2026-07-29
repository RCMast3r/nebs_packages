{ lib
, stdenv
, cmake
, comms
, nebs_demo_comms_cpp
, nebs_demo_c
}:

# End to end check: a downstream CMake project that consumes the generated
# packages purely through `find_package`, exactly as an external user would.
stdenv.mkDerivation {
  pname = "nebs-demo-consumer";
  version = "0.1.0";
  src = ./consumer;

  strictDeps = true;
  nativeBuildInputs = [ cmake ];
  buildInputs = [
    comms
    nebs_demo_comms_cpp
    nebs_demo_c
  ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ctest --output-on-failure
    runHook postCheck
  '';

  meta = {
    description = "Round trip test for the generated nebs_demo protocol packages";
    platforms = lib.platforms.all;
  };
}
