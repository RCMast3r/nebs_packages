{ lib
, stdenv
, cmake
, libxml2
, src
, version ? "8.1.0"
  # Every generator is cheap to build (they are all plain C++ text emitters and
  # none of them needs Qt / emscripten / swig present at build time), so build
  # the lot by default and let `nix-commsdsl` pick what it needs.
, generators ? [
    "commsdsl2comms"
    "commsdsl2c"
    "commsdsl2emscripten"
    "commsdsl2latex"
    "commsdsl2swig"
    "commsdsl2test"
    "commsdsl2tools_qt"
    "commsdsl2wireshark"
  ]
  # Install libcommsdsl + headers so downstream projects can implement their own
  # generators on top of the CommsDSL parser.
, withLibrary ? true
}:

let
  generatorFlag = name:
    lib.cmakeBool
      "COMMSDSL_BUILD_${lib.toUpper name}"
      (builtins.elem name generators);
in
# CommsDSL code generators: turn CommsDSL XML schemas into C++11 protocol
# definitions (and satellite artifacts).
# https://github.com/commschamp/commsdsl
stdenv.mkDerivation {
  pname = "commsdsl";
  inherit version src;

  strictDeps = true;
  nativeBuildInputs = [ cmake ];
  buildInputs = [ libxml2 ];

  cmakeFlags = [
    (lib.cmakeBool "COMMSDSL_WARN_AS_ERR" false)
    (lib.cmakeBool "COMMSDSL_BUILD_UNIT_TESTS" false)
    (lib.cmakeBool "COMMSDSL_INSTALL_APPS" true)
    (lib.cmakeBool "COMMSDSL_INSTALL_LIBRARY" withLibrary)
    # Never let the build reach out to github for its own libxml2 copy.
    (lib.cmakeBool "COMMSDSL_FORCE_INTERNAL_LIBXML_BUILD" false)
  ] ++ map generatorFlag [
    "commsdsl2comms"
    "commsdsl2c"
    "commsdsl2emscripten"
    "commsdsl2latex"
    "commsdsl2swig"
    "commsdsl2test"
    "commsdsl2tools_qt"
    "commsdsl2wireshark"
  ];

  meta = with lib; {
    description = "Code generators producing C++11 binary protocol definitions from CommsDSL schemas";
    homepage = "https://github.com/commschamp/commsdsl";
    license = licenses.asl20;
    mainProgram = "commsdsl2comms";
    platforms = platforms.all;
  };
}
