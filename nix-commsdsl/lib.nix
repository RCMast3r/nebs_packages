{ lib, filter }:
let
  inherit (lib.strings) hasSuffix removePrefix concatStringsSep splitString;
  inherit (lib.lists) flatten concatMap unique;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.filesystem) listFilesRecursive;

  # * Common internal functions used by the code generation
  common = rec {
    /*
      *
      The full set of knobs a CommsDSL package may set, with their defaults.
      Anything a user does not set falls back to the generator's own default,
      which is why most entries are `null` rather than a concrete value.

      - `schemas`            - Schema files, relative to `src`, in the order the
                               generators must process them. `null` means "every
                               `.xml` under `src`, lexicographically sorted".
                               Order matters: the *last* schema is the protocol
                               one, all earlier ones are treated as its
                               dependencies (see the `@other_schema.Field`
                               reference syntax in CommsDSL).
      - `namespace`          - `-n`, force the main namespace / CMake project name.
      - `minRemoteVersion`   - `-m`, minimal supported remote protocol version.
      - `forceSchemaVersion` - `--force-schema-version`.
      - `multipleSchemas`    - `-s`. `null` auto-enables it, which is what you
                               want whenever `dslDeps` is non-empty.
      - `warnAsErr`          - `-w`. Off by default; a schema that trips a new
                               generator warning should not break your build.
      - `codeInput`          - `-c` custom code injection directories, per
                               generator: `{ comms = ./src; c = ./c_src;
                               wireshark = ./ws_src; }`.
      - `extraArgs`          - Escape hatch for raw generator arguments, per
                               generator: `{ comms = [ "--force-main-ns-in-options" ]; }`.
      - `targets`            - Which generated packages to expose, a subset of
                               `supportedTargets`. `null` means all of them. Set
                               it to `[ ]` for a schema that only ever appears in
                               someone else's `dslDeps`: commsdsl2comms and
                               commsdsl2c both crash (SIGSEGV, commsdsl v8.1) on
                               a schema that defines no `<frame>`, so a
                               dependency-only schema has no buildable packages
                               of its own.

      Accepted by commsdsl2comms only:
      - `customization`      - `--customization`, one of "full", "limited", "none".
      - `versionIndependent` - `--version-independent-code`.

      Accepted by commsdsl2c and commsdsl2wireshark only:
      - `messagesList`       - `--messages-list`, restrict generation to the
                               messages named in the given file.
      - `forcePlatform`      - `--force-platform`.
      - `forceInterface`     - `--force-interface`.

      Accepted by commsdsl2wireshark only:
      - `defaultPort`        - `--default-port` baked into the dissector.
    */
    # Generated package suffixes `generateOverlays'` knows how to produce.
    supportedTargets = [
      "comms_cpp"
      "c"
      "wireshark"
    ];

    defaultOptions = {
      schemas = null;
      targets = null;
      namespace = null;
      minRemoteVersion = null;
      forceSchemaVersion = null;
      multipleSchemas = null;
      warnAsErr = false;
      codeInput = { };
      extraArgs = { };

      customization = null;
      versionIndependent = false;

      messagesList = null;
      forcePlatform = null;
      forceInterface = null;

      defaultPort = null;
    };

    /*
      *
      Recursively walk `dslDeps` producing the dependency tree as a list of
      lists. Inner recursion of `recursiveDslDeps`.

      # Type

      ```type
      recursiveDeps :: List -> List
      ```
    */
    recursiveDeps =
      deps:
      concatMap (d: (if d.dslDeps != [ ] then [ (recursiveDeps d.dslDeps) ] else [ ]) ++ [ d ]) deps;

    /*
      *
      Flatten and de-duplicate the tree produced by `recursiveDeps`, preserving
      dependency-before-dependant order. That order is load bearing: CommsDSL
      resolves cross schema references (`@ext1.SomeField`) against schemas that
      were already processed, so a dependency listed after its user is an error.

      # Example

      ```nix
        recursiveDslDeps [ { dslDeps = [ base ]; } ] => [ base { dslDeps = [ base ]; } ]
      ```

      # Type

      ```type
      recursiveDslDeps :: List -> List
      ```
    */
    recursiveDslDeps = deps: unique (flatten (recursiveDeps deps));

    /*
      *
      Absolute paths of the schema files a meta package contributes, in order.

      # Type

      ```type
      schemaFiles :: AttrSet -> List
      ```
    */
    schemaFiles = meta: map (schema: "${meta.src}/${schema}") meta.schemas;

    /*
      *
      The complete, ordered schema file list to hand to a generator for `meta`:
      every transitive dependency first, then the package's own schemas.

      # Type

      ```type
      allSchemaFiles :: AttrSet -> List
      ```
    */
    allSchemaFiles = meta: concatMap schemaFiles (recursiveDslDeps meta.dslDeps ++ [ meta ]);

    /*
      *
      Discover the schema files under `src` when the user did not list them
      explicitly. Returns paths relative to `src`, sorted, so the result is
      stable across evaluations.

      # Type

      ```type
      discoverSchemas :: Path -> List
      ```
    */
    discoverSchemas =
      src:
      let
        prefix = toString src + "/";
      in
      builtins.sort (a: b: a < b) (
        map (file: removePrefix prefix (toString file)) (
          builtins.filter (file: hasSuffix ".xml" (toString file)) (listFilesRecursive src)
        )
      );

    /*
      *
      Best effort extraction of the `name` attribute of the `<schema>` element,
      which is what CommsDSL uses as the C++ main namespace, the generated CMake
      project name and the `find_package` name. Falls back to `fallback` when the
      file cannot be parsed.

      # Type

      ```type
      schemaNameOf :: { file :: Path, fallback :: String } -> String
      ```
    */
    schemaNameOf =
      { file, fallback }:
      let
        match = builtins.match ''.*<schema[^>]*[[:space:]]name[[:space:]]*=[[:space:]]*"([^"]*)".*'' (
          builtins.readFile file
        );
      in
      if match == null then fallback else builtins.head match;

    /*
      *
      Rebuild the metadata attribute set from a derivation produced by
      `mkCommsDslDerivation`. Dependencies are read back out of
      `propagatedBuildInputs` so that they propagate transitively without the
      user having to restate them.

      # Type

      ```type
      loadMeta :: Derivation -> AttrSet
      ```
    */
    loadMeta = drv: {
      inherit (drv) name version;
      inherit (drv.commsdsl) schemas options protocolName;
      src = drv.outPath;
      dslDeps = map loadMeta drv.propagatedBuildInputs;
    };

    # Emit `flag value` only when the option was actually set.
    #
    # Paths are interpolated rather than `toString`ed: `toString ./custom` yields
    # the literal source path with no string context, so the generator would be
    # pointed at a directory that does not exist inside the build sandbox.
    # Interpolation copies the tree to the store and records the dependency.
    optionalArg =
      flag: value:
      lib.optionals (value != null) [
        flag
        (if builtins.isPath value then "${value}" else toString value)
      ];

    /*
      *
      Turn generator options into the command line arguments understood by every
      commsdsl2* tool. `generator` selects which entry of `codeInput` /
      `extraArgs` applies. Options that only some generators accept are added by
      the individual generator derivations instead.

      # Type

      ```type
      commonArgs :: { meta :: AttrSet, generator :: String } -> List
      ```
    */
    commonArgs =
      { meta, generator }:
      let
        opts = meta.options;
        multiple =
          if opts.multipleSchemas != null then
            opts.multipleSchemas
          else
            (builtins.length (allSchemaFiles meta)) > 1;
      in
      lib.optionals multiple [ "-s" ]
      ++ lib.optionals opts.warnAsErr [ "-w" ]
      ++ optionalArg "-n" opts.namespace
      ++ optionalArg "-m" opts.minRemoteVersion
      ++ optionalArg "--force-schema-version" opts.forceSchemaVersion
      ++ optionalArg "-c" (opts.codeInput.${generator} or null)
      ++ (opts.extraArgs.${generator} or [ ]);

    /*
      *
      Arguments accepted by the generators that pick a subset of the protocol to
      emit (commsdsl2c and commsdsl2wireshark).

      # Type

      ```type
      messageSelectionArgs :: AttrSet -> List
      ```
    */
    messageSelectionArgs =
      meta:
      optionalArg "--messages-list" meta.options.messagesList
      ++ optionalArg "--force-platform" meta.options.forcePlatform
      ++ optionalArg "--force-interface" meta.options.forceInterface;

    /*
      *
      `-V` is only accepted in strict `<major>.<minor>.<patch>` form, so skip it
      for versions that do not look like that rather than failing the build.

      # Type

      ```type
      versionArgs :: String -> List
      ```
    */
    versionArgs =
      version:
      lib.optionals (builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" version != null) [ "-V" version ];

    slashToUnderscore = namespace: concatStringsSep "_" (splitString "/" namespace);
  };

  # * Public utilities for users of the nix-commsdsl library
  utilities = {
    /*
      *
      Filter a source tree down to a single namespace, for repositories that
      keep several protocols side by side.

      # Example

      ```nix
        srcFromNamespace { root = ./schema; namespace = "vehicle/can"; } => /nix/store/...
      ```

      # Type

      ```type
      srcFromNamespace :: { root :: Path, namespace :: String } -> Path
      ```
    */
    srcFromNamespace =
      { root, namespace }:
      filter {
        inherit root;
        include = [ namespace ];
      };

    /*
      *
      Turn the namespace used for source filtering into a package name.

      # Example

      ```nix
        nameFromNamespace "vehicle/can" => "vehicle_can"
      ```

      # Type

      ```type
      nameFromNamespace :: String -> String
      ```
    */
    nameFromNamespace = namespace: common.slashToUnderscore namespace;

    /*
      *
      Convert the attribute set of overlays returned by `generateOverlays'` into
      a list, so it can be handed to `import nixpkgs { overlays = ...; }`.

      # Type

      ```type
      overlayToList :: AttrSet -> List
      ```
    */
    overlayToList = overlay_set: mapAttrsToList (_: overlay: overlay) overlay_set;
  };
in
{
  inherit common utilities;
}
