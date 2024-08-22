{
  description = "my packages. im tired of making new repos for nix packages and im too lazy to push em up to nixpkgs";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devshell.url = "github:numtide/devshell";
    nix-proto.url = "github:notalltim/nix-proto";

    flow-ipc-src = {
      url = "github:Flow-IPC/flow?submodules=1";
      flake = false;
    };
    commsdsl-src = {
      url = "github:commschamp/commsdsl";
      flake = false;
    };
    commslib-src = {
      url = "github:RCMast3r/comms";
      flake = false;
    };

    foxglove-ws-protocol-src = {
      url = "github:RCMast3r/ws-protocol";
      flake = false;
    };

    libsocketcanpp-src = {
      url = "github:SimonCahill/libsockcanpp";
      flake = false;
    };

    dbcppp-src = {
      type = "git";
      url = "https://github.com/xR3b0rn/dbcppp.git";
      submodules = true;
      flake = false;
    };

  };
  outputs = { self, nixpkgs, flow-ipc-src, flake-parts, devshell, commsdsl-src, commslib-src, foxglove-ws-protocol-src, libsocketcanpp-src, dbcppp-src, ... }@inputs:
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
            foxglove-ws-protocol-cpp = pkgs.callPackage ./foxglove_ws_protocol_cpp.nix { src = foxglove-ws-protocol-src; };
            libsocketcanpp = pkgs.callPackage ./libsocketcanpp.nix {src = libsocketcanpp-src;};
            dbcppp = pkgs.callPackage ./dbcppp.nix {src = dbcppp-src; };
          in
          {
            packages.commsdsl = commsdsl;
            packages.commslib = commslib;
            packages.default = flow-ipc;
            packages.foxglove-ws-protocol-cpp = foxglove-ws-protocol-cpp;
            packages.libsocketcanpp = libsocketcanpp;
            packages.dbcppp = dbcppp;
            overlayAttrs = {
              inherit (config.packages) default commsdsl commslib foxglove-ws-protocol-cpp libsocketcanpp;
            };
            legacyPackages =
              import nixpkgs {
                inherit system;
                overlays = [ (final: _: {flow-ipc = final.callPackage ./flow-ipc.nix { src = flow-ipc-src; }; }) ];
              };

          };
      };
}
