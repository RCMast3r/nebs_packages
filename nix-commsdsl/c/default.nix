{ lib }:
let
  inherit (lib)
    loadMeta
    allSchemaFiles
    commonArgs
    versionArgs
    messageSelectionArgs
    optionalArg
    ;
in
/*
  *
  commsdsl2c derivation: emits a "C" facade over the C++ protocol definition
  produced by commsdsl2comms and builds it into a library.

  The generated CMake project locates the C++ side with
  `find_package(<protocol>)`, which is why `<name>_comms_cpp` is both a build
  input and propagated: consumers of a statically linked facade still need the
  protocol target to exist.

  # Type

  ```
  c :: { __commsdsl_internal_meta_package :: Derivation, ... } -> Derivation
  ```
*/
{
  stdenv,
  cmake,
  commsdsl,
  comms,
  pkgs,
  __commsdsl_internal_meta_package,
}:
let
  dsl = loadMeta __commsdsl_internal_meta_package;
  opts = dsl.options;
  schemas = allSchemaFiles dsl;
  # The C facade wraps the code emitted by commsdsl2comms for the very same
  # schemas, so it always builds against this protocol's own C++ package.
  protocolCpp = pkgs.${dsl.name + "_comms_cpp"};
  generatorArgs =
    commonArgs {
      meta = dsl;
      generator = "c";
    }
    ++ versionArgs dsl.version
    ++ messageSelectionArgs dsl;
in
stdenv.mkDerivation {
  name = dsl.name + "_c";
  inherit (dsl) version;
  src = dsl.src;

  dontUnpack = true;

  strictDeps = true;
  nativeBuildInputs = [
    cmake
    commsdsl
  ];

  propagatedBuildInputs = [
    comms
    protocolCpp
  ];

  preConfigure = ''
    runHook preGenerate

    echo "commsdsl2c: generating ${dsl.protocolName} C interface from ${
      toString (builtins.length schemas)
    } schema file(s)"
    commsdsl2c ${lib.escapeShellArgs generatorArgs} \
      -o "$NIX_BUILD_TOP/generated" \
      ${lib.escapeShellArgs schemas}

    runHook postGenerate

    cmakeDir="$NIX_BUILD_TOP/generated"
  '';

  cmakeFlags = [
    (lib.cmakeBool "OPT_FIND_COMMS" true)
    (lib.cmakeBool "OPT_FIND_PROTOCOL" true)
    # The generated project turns on -Werror together with a very broad warning
    # set; a compiler newer than the one upstream tested against should not
    # break the build of code nobody hand wrote.
    (lib.cmakeBool "OPT_WARN_AS_ERR" false)
  ]
  # Only override the protocol name the generator baked in when the user forced
  # the namespace, so a mis-detected schema name can never break the lookup.
  ++ lib.optionals (opts.namespace != null) [
    (lib.cmakeFeature "OPT_PROTOCOL_NAME" opts.namespace)
  ]
  # A static facade exports its PRIVATE link dependencies as $<LINK_ONLY:cc::…>
  # without a matching find_dependency in the generated config file, so shared
  # is the only flavour that imports cleanly downstream.
  ++ lib.optionals (!stdenv.hostPlatform.isStatic) [ (lib.cmakeBool "BUILD_SHARED_LIBS" true) ];

  separateDebugInfo = true;

  passthru = {
    inherit (dsl) protocolName;
    schemaFiles = schemas;
    commsdslMeta = dsl;
  };

  meta = {
    description = "CommsDSL generated C interface for the ${dsl.protocolName} protocol";
    homepage = "https://commschamp.github.io/";
    platforms = lib.platforms.all;
  };
}
