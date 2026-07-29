{ lib
, stdenv
, cmake
, src
, version ? "5.5.2"
  # Install `comms` / `cc_comms` cmake config aliases next to the canonical
  # `LibComms` one. Generated protocol projects only look for `LibComms`, but
  # hand written projects in the wild use all three spellings.
, withCmakeConfigAliases ? true
}:

# The COMMS library: header only C++11 protocol definition framework.
# https://github.com/commschamp/comms
stdenv.mkDerivation {
  pname = "comms";
  inherit version src;

  strictDeps = true;
  nativeBuildInputs = [ cmake ];

  cmakeFlags = [
    (lib.cmakeBool "CC_COMMS_BUILD_UNIT_TESTS" false)
    (lib.cmakeBool "CC_COMMS_WARN_AS_ERR" false)
    (lib.cmakeBool "CC_COMMS_EXTALL_EXTRA_CONFIGS" withCmakeConfigAliases)
  ];

  # Headers only, there is no compiled output to fix up.
  dontStrip = true;

  meta = with lib; {
    description = "Header only C++11 library for implementing binary communication protocols";
    homepage = "https://github.com/commschamp/comms";
    license = licenses.mpl20;
    platforms = platforms.all;
  };
}
