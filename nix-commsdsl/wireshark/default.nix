{ lib }:
let
  inherit (lib)
    loadMeta
    allSchemaFiles
    commonArgs
    messageSelectionArgs
    optionalArg
    ;
in
/*
  *
  commsdsl2wireshark derivation: emits the lua dissector for the protocol.

  The generator produces `<schema>.lua` (the dissector itself, returned as a lua
  module) and `<schema>_plug.lua` (the wireshark entry point that requires it and
  wires up the transport). They are installed side by side, which is what the
  entry point expects since it extends `package.path` with its own directory.

  They deliberately do *not* go into wireshark's auto-load plugin directory:
  wireshark would source both files, and the dissector registering its `Proto`
  twice is a hard error. Load the plugin explicitly instead:

  ```
  wireshark -X lua_script:$(nix eval --raw .#my_protocol_wireshark.pluginScript)
  ```

  or use the `<protocol>-wireshark` / `<protocol>-tshark` wrappers produced when
  `withWrappers` is set.

  # Type

  ```
  wireshark :: { __commsdsl_internal_meta_package :: Derivation, ... } -> Derivation
  ```
*/
{
  stdenvNoCC,
  commsdsl,
  lua5_4,
  makeWrapper,
  wireshark,
  wireshark-cli,
  __commsdsl_internal_meta_package,
  # Emit `<protocol>-wireshark` and `<protocol>-tshark` launchers with the
  # dissector preloaded. Off by default: wireshark pulls in Qt.
  withWrappers ? false,
}:
let
  dsl = loadMeta __commsdsl_internal_meta_package;
  opts = dsl.options;
  schemas = allSchemaFiles dsl;
  luaDir = "share/wireshark/${dsl.protocolName}";
  generatorArgs =
    commonArgs {
      meta = dsl;
      generator = "wireshark";
    }
    ++ messageSelectionArgs dsl
    ++ optionalArg "--default-port" opts.defaultPort;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  name = dsl.name + "_wireshark";
  inherit (dsl) version;
  src = dsl.src;

  dontUnpack = true;
  dontConfigure = true;

  strictDeps = true;
  nativeBuildInputs = [
    commsdsl
    lua5_4
  ] ++ lib.optionals withWrappers [ makeWrapper ];

  buildPhase = ''
    runHook preBuild

    echo "commsdsl2wireshark: generating ${dsl.protocolName} dissector from ${
      toString (builtins.length schemas)
    } schema file(s)"
    commsdsl2wireshark ${lib.escapeShellArgs generatorArgs} \
      -o "$NIX_BUILD_TOP/generated" \
      ${lib.escapeShellArgs schemas}

    # The dissector is the whole deliverable here, so a syntax error in it must
    # fail the build rather than surface as a cryptic wireshark popup.
    for script in "$NIX_BUILD_TOP"/generated/*.lua; do
      luac -p "$script"
    done

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/${luaDir}"
    cp "$NIX_BUILD_TOP"/generated/*.lua "$out/${luaDir}/"

    ${lib.optionalString withWrappers ''
      makeWrapper ${lib.getExe' wireshark "wireshark"} "$out/bin/${dsl.protocolName}-wireshark" \
        --add-flags "-X lua_script:$out/${luaDir}/${dsl.protocolName}_plug.lua"
      makeWrapper ${lib.getExe' wireshark-cli "tshark"} "$out/bin/${dsl.protocolName}-tshark" \
        --add-flags "-X lua_script:$out/${luaDir}/${dsl.protocolName}_plug.lua" \
        --add-flags "-O ${dsl.protocolName}"
    ''}

    runHook postInstall
  '';

  passthru = {
    inherit (dsl) protocolName;
    schemaFiles = schemas;
    commsdslMeta = dsl;
    # Pass this to `wireshark -X lua_script:...`.
    pluginScript = "${finalAttrs.finalPackage}/${luaDir}/${dsl.protocolName}_plug.lua";
    luaPath = "${finalAttrs.finalPackage}/${luaDir}";
  };

  meta = {
    description = "CommsDSL generated wireshark lua dissector for the ${dsl.protocolName} protocol";
    homepage = "https://commschamp.github.io/";
    platforms = lib.platforms.all;
  };
})
