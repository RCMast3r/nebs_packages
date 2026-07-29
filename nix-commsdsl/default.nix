{
  nix_lib,
  filter,
}:
let
  internal_lib = import ./lib.nix {
    inherit filter;
    lib = nix_lib;
  };
  inherit (internal_lib) utilities;

  # Internal lib used by the code generation and the nix generation
  lib = nix_lib // internal_lib.common // internal_lib.utilities;

  # Generation functions
  generation = import ./generation.nix { inherit lib; };
in
{
  inherit (generation) mkCommsDslDerivation generateOverlays';
  inherit (utilities) srcFromNamespace nameFromNamespace overlayToList;
  inherit (internal_lib.common) defaultOptions supportedTargets;
}
