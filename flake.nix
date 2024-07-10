{
  description = "my packages. im tired of making new repos for nix packages and im too lazy to push em up to nixpkgs";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devshell.url = "github:numtide/devshell";
    flow-ipc-src = {
      url = "github:Flow-IPC/flow?submodules=1";
      flake = false;
    };
    commsdsl-src = {
      url = "github:commschamp/commsdsl";
      flake = false;
    };
    commslib-src = {
      url = "github:commschamp/comms";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, flow-ipc-src, flake-parts, devshell, commsdsl-src, commslib-src, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; }
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];
        imports = [
          inputs.flake-parts.flakeModules.easyOverlay
          inputs.devshell.flakeModule
        ];
        perSystem = { config, pkgs, system, ... }:
          let
            flow-ipc = pkgs.callPackage ./flow-ipc.nix { src = flow-ipc-src; };
            commsdsl = pkgs.callPackage ./commsdsl.nix { src = commsdsl-src; };
            commslib = pkgs.callPackage ./commslib.nix { src = commslib-src; };
          in
          {
            packages.commsdsl = commsdsl;
            packages.commslib = commslib;
            packages.default = flow-ipc;
            overlayAttrs = {
              inherit (config.packages) default;
              inherit (config.packages) commsdsl;
              inherit (config.packages) commslib;
            };
            legacyPackages =
              import nixpkgs {
                inherit system;
                overlays = [ (final: _: {flow-ipc = final.callPackage ./flow-ipc.nix { src = flow-ipc-src; }; }) ];
              };

          };
      };
}
