{ lib }:
let
  inherit (lib)
    loadMeta
    allSchemaFiles
    commonArgs
    versionArgs
    optionalArg
    ;
in
/*
  *
  commsdsl2comms derivation: runs the generator over the schemas carried by
  `__commsdsl_internal_meta_package` and builds the CMake project it emits.

  The result is the headers only protocol definition library plus its
  `<protocol>Config.cmake`, so downstream CMake projects can do

  ```cmake
  find_package (<protocol> REQUIRED)
  target_link_libraries (my_app PRIVATE cc::<protocol>)
  ```

  # Type

  ```
  commsCpp :: { __commsdsl_internal_meta_package :: Derivation, ... } -> Derivation
  ```
*/
{
  stdenv,
  cmake,
  commsdsl,
  comms,
  __commsdsl_internal_meta_package,
  # Build the doxygen documentation of the protocol into $doc. Off by default
  # because it roughly doubles the build time of a large protocol.
  withDocs ? false,
  doxygen,
  graphviz,
}:
let
  dsl = loadMeta __commsdsl_internal_meta_package;
  opts = dsl.options;
  schemas = allSchemaFiles dsl;
  generatorArgs =
    commonArgs {
      meta = dsl;
      generator = "comms";
    }
    ++ versionArgs dsl.version
    ++ optionalArg "--customization" opts.customization
    ++ lib.optionals opts.versionIndependent [ "--version-independent-code" ];
in
stdenv.mkDerivation {
  name = dsl.name + "_comms_cpp";
  inherit (dsl) version;
  src = dsl.src;

  # The schemas are referenced by absolute store path on the generator command
  # line, so there is nothing to unpack.
  dontUnpack = true;

  strictDeps = true;
  nativeBuildInputs = [
    cmake
    commsdsl
  ] ++ lib.optionals withDocs [ doxygen graphviz ];

  # Header only and unconditionally `#include`d by consumers, so it has to be
  # propagated rather than merely available here.
  propagatedBuildInputs = [ comms ];

  outputs = [ "out" ] ++ lib.optionals withDocs [ "doc" ];

  preConfigure = ''
    runHook preGenerate

    echo "commsdsl2comms: generating ${dsl.protocolName} from ${
      toString (builtins.length schemas)
    } schema file(s)"
    commsdsl2comms ${lib.escapeShellArgs generatorArgs} \
      -o "$NIX_BUILD_TOP/generated" \
      ${lib.escapeShellArgs schemas}

    runHook postGenerate

    cmakeDir="$NIX_BUILD_TOP/generated"
  '';

  cmakeFlags = [
    # `comms` is propagated, so cmake finds LibComms through CMAKE_PREFIX_PATH
    # and records the `cc::comms` dependency on the exported target.
    (lib.cmakeBool "OPT_REQUIRE_COMMS_LIB" true)
  ];

  postBuild = lib.optionalString withDocs ''
    make "doc_${dsl.protocolName}"
  '';

  postInstall = lib.optionalString withDocs ''
    mkdir -p $doc/share/doc
    mv $out/share/doc/* $doc/share/doc/
  '';

  passthru = {
    inherit (dsl) protocolName;
    schemaFiles = schemas;
    commsdslMeta = dsl;
  };

  meta = {
    description = "CommsDSL generated C++11 protocol definition for ${dsl.protocolName}";
    homepage = "https://commschamp.github.io/";
    platforms = lib.platforms.all;
  };
}
