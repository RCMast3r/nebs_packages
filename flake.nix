{
  description = "my packages. im tired of making new repos for nix packages and im too lazy to push em up to nixpkgs";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flow-ipc-src = {
      url = "github:Flow-IPC/flow?submodules=1";
      flake = false;
    };
    devshell.url = "github:numtide/devshell";
  };

  outputs = { self, nixpkgs, flow-ipc-src, flake-parts, devshell, ... }@inputs:
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
        in
        {
          packages.default = flow-ipc;

          overlayAttrs = {
            inherit (config.packages) default;
          };
          legacyPackages = flow-ipc;
          
        };
    };


}
