# nix-commsdsl

Automatic overlay generation and dependency management for protocol code
generated from [CommsDSL](https://commschamp.github.io/commsdsl_spec/) XML
schemas, in the style of [nix-proto](https://github.com/notalltim/nix-proto).

You describe a protocol once, as schema files plus a name and a version. You get
back packaged, pre-generated drivers for it: a C++11 protocol definition library,
a C facade, and a wireshark dissector, each a normal derivation with normal
`find_package` metadata.

## Code Generation

Every entry you pass to `generateOverlays'` produces the schema package itself
plus one package per generation target (`base_name` is the name given to
`mkCommsDslDerivation`):

| package                  | generator             | contents                                                                  |
| ------------------------ | --------------------- | ------------------------------------------------------------------------- |
| `base_name`              | –                     | the schema files in the store, carrying the metadata and the dependencies  |
| `base_name_comms_cpp`    | `commsdsl2comms`      | headers only C++11 protocol definition, exported as `cc::<protocol>`       |
| `base_name_c`            | `commsdsl2c`          | shared library with a C interface, exported as `cc::<protocol>_c`          |
| `base_name_wireshark`    | `commsdsl2wireshark`  | lua dissector under `share/wireshark/<protocol>/`                          |

Adding a target means adding a directory next to `./comms`, `./c` and
`./wireshark` and listing it in `targetDerivations` in `./generation.nix`.
`commsdsl` in this repo builds every upstream generator, including
`commsdsl2test`, `commsdsl2swig`, `commsdsl2emscripten` and `commsdsl2latex`, so
no packaging change is needed to reach them.

## Dependency Management

`dslDeps` declares that this schema references another one, and it is transitive:
listing a direct dependency is enough, the whole chain is prepended to every
generator invocation in dependency order.

Note the difference from protobuf. CommsDSL has no separate compilation unit per
schema — the generators process an ordered list of schema files where the last is
the protocol one and the earlier ones are its dependencies, and the output tree
contains a namespace for each. So `dslDeps` propagates *schemas*, not generated
libraries: `my_protocol_comms_cpp` contains `include/base_protocol/…` as well as
its own headers, rather than linking a separate `base_protocol_comms_cpp`.

## Utilities

Available under `nix-commsdsl`, mirroring `nix-proto.lib`:

- `overlayToList` — convert the overlay set returned by `generateOverlays'` to a list
- `srcFromNamespace` — filter a shared schema root down to one protocol
- `nameFromNamespace` — turn `"vehicle/can"` into `"vehicle_can"`
- `defaultOptions` — every generator knob with its default, documented inline in [`lib.nix`](./lib.nix)

## Usage

The interface follows `mkDerivation` with a few tweaks. Derivations are created
in the context of `generateOverlays'`. **NOTE** there is a limitation that
requires the name given to the attribute set to match the name given to the
derivation, e.g. `base_protocol == base_protocol`.

### Generation

```nix
{
  overlays = nix-commsdsl.generateOverlays' {
    base_protocol = nix-commsdsl.mkCommsDslDerivation {
      name = "base_protocol";
      version = "1.0.1";
      src = ./schema/base;
      # Field-only schemas define no <frame>, so they have no packages of their
      # own — see "Known upstream issue" below.
      targets = [ ];
    };

    my_protocol =
      { base_protocol }:
      nix-commsdsl.mkCommsDslDerivation {
        name = "my_protocol";
        version = "1.2.3";
        src = ./schema/mine;
        dslDeps = [ base_protocol ];

        # optional generator knobs, see `defaultOptions`
        customization = "none";
        defaultPort = 30000;
        codeInput.comms = ./custom_cpp_snippets;
      };
  };
}
```

Schema files are discovered as every `.xml` under `src`, sorted, which is why
`10-base.xml` / `20-main.xml` style naming works. When the order matters and the
names do not express it, set `schemas` explicitly:

```nix
schemas = [ "Common.xml" "Protocol.xml" ];
```

### Overlay

The returned attribute set contains one overlay per entry, named with `_overlay`
appended, plus a `default` composing all of them.

```nix
{
  overlays = {
    base_protocol_overlay = final: prev: { ... };
    my_protocol_overlay = final: prev: { ... };
    default = final: prev: { ... };
  };
}
```

The generated packages need `comms` and `commsdsl` in the package set, so apply
this repo's overlay alongside your generated ones.

### Flake Support

```nix
{
  inputs.nebs-packages.url = "github:RCMast3r/nebs_packages";

  outputs = { nixpkgs, flake-utils, nebs-packages, ... }:
    let
      nix-commsdsl = nebs-packages.nix-commsdsl;
      overlays = nix-commsdsl.generateOverlays' {
        my_protocol = nix-commsdsl.mkCommsDslDerivation {
          name = "my_protocol";
          version = "1.2.3";
          src = ./schema;
        };
      };
    in
    { inherit overlays; }
    // flake-utils.lib.eachDefaultSystem (system: {
      legacyPackages = import nixpkgs {
        inherit system;
        overlays = [ nebs-packages.overlays.default ] ++ nix-commsdsl.overlayToList overlays;
      };
    });
}
```

Then `pkgs.my_protocol_comms_cpp` is a normal build input:

```cmake
find_package (my_protocol REQUIRED)
target_link_libraries (my_app PRIVATE cc::my_protocol)
```

### Wireshark

The dissector is *not* installed into wireshark's auto-load plugin directory. The
generator emits two files, and wireshark sourcing both would register the `Proto`
twice, which is a hard error. Load the entry point explicitly:

```console
$ wireshark -X lua_script:$(nix eval --raw .#my_protocol_wireshark.pluginScript)
```

Set `withWrappers = true` (via `overrideAttrs`/`override`) to get
`my_protocol-wireshark` and `my_protocol-tshark` launchers with the script
already wired up. It is off by default because wireshark pulls in Qt.

## Known upstream issue

`commsdsl2comms` and `commsdsl2c` v8.1 **segfault** while writing `doc/main.dox`
for any schema that defines no `<frame>`. A schema that only contributes shared
fields therefore has no buildable packages of its own; set `targets = [ ]` on it
so the attributes fail with an explanation instead of a signal 11. It still works
perfectly well as a `dslDeps` entry, which is the only thing such a schema is for.
`commsdsl2wireshark` is unaffected.

## Example

[`./example`](./example) is a two-schema protocol wired up end to end:
`nebs_base` contributes fields, `nebs_demo` depends on it and defines the messages
and the frame. [`./example/consumer`](./example/consumer) is a plain CMake project
that consumes the results through `find_package` only, and round trips a message
through both the C++ and the C API. Both run under `nix flake check`.
