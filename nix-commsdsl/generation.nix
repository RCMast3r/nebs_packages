{ lib }:
rec {
  inherit (lib.attrsets) mapAttrs' nameValuePair;
  inherit (lib.strings) removeSuffix removePrefix;
  inherit (lib.fixedPoints) composeManyExtensions;
  inherit (lib)
    overlayToList
    defaultOptions
    supportedTargets
    discoverSchemas
    schemaNameOf
    ;

  /*
    *
    Make a derivation that installs the CommsDSL schema files found at `src`
    into the store and carries the metadata needed to drive the commsdsl2*
    generators. Combined with `generateOverlays'` it produces a set of packages
    holding the generated protocol code. This mimics the `mkDerivation` pattern
    for building overlays.

    The minimum set of information needed is
    - `src`  - path to the CommsDSL XML schema files
    - `name` - base name for the generated packages

    Optional additional information
    - `version`  - version of the protocol, also stamped into the generated
                   code via the generators' `-V` option
    - `dslDeps`  - list of packages produced by this function whose schemas this
                   one references. Their schema files are prepended (transitively,
                   dependency first) to the generator invocation, which is how
                   CommsDSL cross schema references such as `@base.SomeField`
                   resolve.
    - any key from `nix-commsdsl.lib.defaultOptions` - see its documentation for
      the full list of generator knobs (`namespace`, `customization`,
      `codeInput`, ...).

    Note that unlike protobuf, CommsDSL has no separate compilation unit per
    schema: a protocol that depends on another gets the dependency's namespaces
    generated into its own output tree. `dslDeps` therefore propagates *schemas*,
    not generated libraries.

    **NOTE**: The name given to this function must match the attribute name
    passed to `generateOverlays'` for this derivation.

    # Example

    ```nix
    my_protocol = { base_protocol }: mkCommsDslDerivation {
      name = "my_protocol";
      version = "1.2.3";
      src = ./schema;
      dslDeps = [ base_protocol ];
    }
    => { base_protocol } : { stdenvNoCC } : stdenvNoCC.mkDerivation {
      name = "my_protocol";
      version = "1.2.3";
      src = ./schema;
      propagatedBuildInputs = [ base_protocol ];
      # other metadata
    }
    ```

    # Type

    ```
    mkCommsDslDerivation :: AttrSet -> ({ stdenvNoCC :: AttrSet } -> Derivation)
    ```

    - [set] User provided attribute set used to build the internal derivation.

    - [returns] derivation made with a combination of custom and user provided
      attributes using `stdenvNoCC`.
  */
  mkCommsDslDerivation =
    set:
    { stdenvNoCC }:
    let
      options = defaultOptions // (builtins.intersectAttrs defaultOptions set);
      schemas = if options.schemas != null then options.schemas else discoverSchemas set.src;
      # The protocol schema is the last one processed; its <schema name="..."> is
      # the C++ main namespace, the generated CMake project name and what
      # downstream `find_package` calls ask for.
      protocolName =
        if options.namespace != null then
          options.namespace
        else if schemas == [ ] then
          set.name
        else
          schemaNameOf {
            file = set.src + "/${lib.last schemas}";
            fallback = set.name;
          };
    in
    stdenvNoCC.mkDerivation (
      (builtins.removeAttrs set ([ "dslDeps" ] ++ builtins.attrNames defaultOptions))
      // {
        version = set.version or "0.0.0";
        propagatedBuildInputs = set.dslDeps or [ ];

        installPhase = ''
          runHook preInstall
          cp -r . $out
          runHook postInstall
        '';

        passthru = (set.passthru or { }) // {
          commsdsl = {
            inherit schemas options protocolName;
          };
        };
      }
    );

  # * commsdsl2comms: C++11, headers only protocol definition library
  generateCommsCpp = import ./comms { inherit lib; };
  # * commsdsl2c: "C" interface library wrapping the generated C++ code
  generateC = import ./c { inherit lib; };
  # * commsdsl2wireshark: lua dissector for wireshark / tshark
  generateWireshark = import ./wireshark { inherit lib; };

  # The generator behind each supported target suffix.
  targetDerivations = {
    comms_cpp = generateCommsCpp;
    c = generateC;
    wireshark = generateWireshark;
  };

  /*
    *
    Create the set of derivations to evaluate with `generateOverlay'`.

    Note that this covers *every* supported target regardless of the package's
    `targets` option. The set of attribute names an overlay defines cannot depend
    on the package set the overlay is being applied to, so `targets` is honoured
    by the attribute *values* in `createTargetOverlay` instead.

    # Example

    ```nix
      generateDerivations "my_protocol"
      => { my_protocol_comms_cpp_drv = Derivation; my_protocol_c_drv = Derivation; ... }
    ```

    # Type

    ```
    generateDerivations :: String -> AttrSet
    ```

    - [name] Base name of the generated packages.

    - [returns] Attribute set of code generation derivations.
  */
  generateDerivations =
    name: mapAttrs' (target: drv: nameValuePair "${name}_${target}_drv" drv) targetDerivations;

  /*
    *
    Determine whether a derivation is a plain `mkCommsDslDerivation` result or a
    user function taking its dependencies as arguments, and produce the right
    number of `callPackage` layers.

    # Example

    ```nix
    # produces a double `callPackage`
    evaluateCommsDslDerivation ({ dep }: { stdenvNoCC }: {})
    # produces a single `callPackage`
    evaluateCommsDslDerivation ({ stdenvNoCC }: {})
    ```

    # Type

    ```
    evaluateCommsDslDerivation :: (AttrSet -> (AttrSet -> Derivation)) -> (PkgSet -> Package)
    evaluateCommsDslDerivation :: (AttrSet -> Derivation) -> (PkgSet -> Package)
    ```

    - [input] function to evaluate

    - [returns] function to be called in an overlay function
  */
  evaluateCommsDslDerivation =
    input:
    let
      inherit (lib.trivial) functionArgs;
      # Check if the user passed a function or if this is the internal derivation
      doubleCall = !((functionArgs input) ? stdenvNoCC);
    in
    if doubleCall then final: (final.callPackage (final.callPackage input { }) { }) else final: (final.callPackage input { });

  /*
    *
    Internal function that takes the meta derivation and produces the set of
    packages for every supported codegen target. Each generator derivation is
    called with a specific `callPackage` signature

    ```nix
    target_specific_name = final.callPackage target_specific_derivation { inherit __commsdsl_internal_meta_package; };
    ```

    which passes down the marker package holding the schemas and the metadata
    needed to run the generator.

    # Type

    ```
    createTargetOverlay :: String -> Overlay -> (PkgSet -> PkgSet -> AttrSet)
    ```

    - [name] name to use for the overlay
    - [dslOverlay] meta derivation used to generate the codegen derivations

    - [returns] overlay function producing an attribute set of target specific packages.
  */
  createTargetOverlay =
    name: dslOverlay:
    final: _:
    let
      dslPackage = dslOverlay final;

      metaPackage =
        lib.throwIf (name != dslPackage.name)
          "name passed to `generateOverlays'` (${name}) and `mkCommsDslDerivation` (${dslPackage.name}) do not match ${name} != ${dslPackage.name}"
          dslPackage;

      requested = dslPackage.commsdsl.options.targets;
      unknown = lib.subtractLists supportedTargets (if requested == null then [ ] else requested);
      selected =
        lib.throwIf (unknown != [ ])
          "unknown nix-commsdsl target(s) ${toString unknown} requested by ${name}, expected a subset of ${toString supportedTargets}"
          (if requested == null then supportedTargets else requested);
    in
    mapAttrs' (
      key: value:
      let
        target = removeSuffix "_drv" (removePrefix "${name}_" key);
      in
      nameValuePair (removeSuffix "_drv" key) (
        if builtins.elem target selected then
          final.callPackage value { __commsdsl_internal_meta_package = metaPackage; }
        else
          throw "${name} does not produce a '${target}' package: its `targets` option is ${toString selected}"
      )
    ) (generateDerivations name);

  /*
    *
    Internal function turning a single meta derivation into an overlay exposing
    both the schema package itself (so dependencies propagate) and every
    generated target package.

    # Example

    ```nix
      generateOverlay' { drv = {}: {}; name = "my_protocol"; }
      => final: prev: { my_protocol = ...; my_protocol_comms_cpp = ...; ... }
    ```

    # Type

    ```
    generateOverlay' :: { drv :: Derivation, name :: String } -> (PkgSet -> PkgSet -> Package)
    ```
  */
  generateOverlay' =
    { drv, name }:
    let
      dslOverlayComponent = evaluateCommsDslDerivation drv;
    in
    composeManyExtensions [
      # Contains the package used to propagate schema dependencies
      (final: _: { ${name} = dslOverlayComponent final; })
      # Contains the target specific packages
      (createTargetOverlay name dslOverlayComponent)
    ];

  /*
    *
    Generate a set of overlays from an attribute set of derivations produced by
    `mkCommsDslDerivation`. The overlays are returned as an attribute set using
    the same names with '_overlay' appended, and can be flattened with
    `overlayToList` to pass to `legacyPackages`. Additionally a `default`
    attribute composes all of them.

    # Example

    ```nix
    generateOverlays' {
      my_protocol = mkCommsDslDerivation {
        name = "my_protocol";
        version = "1.2.3";
        src = ./schema;
      };
    } => {
           my_protocol_overlay = final: prev: ...;
           default = final: prev: ...;
         }
    ```

    # Type

    ```
    generateOverlays' :: AttrSet -> AttrSet
    ```

    - [set] User provided attribute set of calls to `mkCommsDslDerivation`

    - [returns] Attribute set of overlays (functions of the form final: prev:)
  */
  generateOverlays' =
    set:
    let
      overlayAttrs = mapAttrs' (
        name: drv: nameValuePair (name + "_overlay") (generateOverlay' { inherit drv name; })
      ) set;

      default = composeManyExtensions (overlayToList overlayAttrs);
    in
    overlayAttrs // { inherit default; };
}
