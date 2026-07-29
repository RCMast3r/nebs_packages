nix-commsdsl:
nix-commsdsl.generateOverlays' {
  # A schema that only contributes fields. It defines no <frame>, which
  # commsdsl2comms and commsdsl2c cannot generate a project for, so it exposes no
  # generated packages of its own and exists purely to be depended on.
  nebs_base = nix-commsdsl.mkCommsDslDerivation {
    name = "nebs_base";
    version = "1.0.0";
    src = ./base;
    targets = [ ];
  };

  # The protocol proper. Its schema references @nebs_base fields, so nebs_base's
  # schema file is prepended to every generator invocation.
  nebs_demo =
    { nebs_base }:
    nix-commsdsl.mkCommsDslDerivation {
      name = "nebs_demo";
      version = "0.1.0";
      src = ./demo;
      dslDeps = [ nebs_base ];
      defaultPort = 30000;
    };
}
