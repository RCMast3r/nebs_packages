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

    foxglove-mcap-src = {
      url = "github:RCMast3r/mcap";
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
      url = "https://github.com/RCMast3r/dbcppp.git";
      submodules = true;
      flake = false;
    };

    gtsam-src = {
      url = "github:borglab/gtsam/4.2.0";
      flake = false;
    };

    soem-src = {
      url = "github:OpenEtherCATsociety/SOEM";
      flake = false;
    };
    glim-src = {
      url = "github:RCMast3r/glim";
      flake = false;
    };
    gtsam-points-src = {
      url = "github:RCMast3r/gtsam_points";
      flake = false;
    };
    
    glim-ros2-src = {
      url = "github:koide3/glim_ros2";
      flake = false;
    };

  };
  outputs = { self, nixpkgs, flow-ipc-src, flake-parts, devshell, commsdsl-src, commslib-src, foxglove-ws-protocol-src, libsocketcanpp-src, foxglove-mcap-src, dbcppp-src, gtsam-src, soem-src, glim-src, gtsam-points-src, glim-ros2-src, ... }@inputs:
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
            mcap = pkgs.callPackage ./mcap.nix { src = "${foxglove-mcap-src}/cpp";};
            libsocketcanpp = pkgs.callPackage ./libsocketcanpp.nix {src = libsocketcanpp-src;};
            dbcppp = pkgs.callPackage ./dbcppp.nix { src = dbcppp-src; };
            gtsam_pkg = pkgs.callPackage ./gtsam.nix { src = gtsam-src; };
            soem = pkgs.callPackage ./soem.nix {src = soem-src; };
            gtsam-points = pkgs.callPackage ./gtsam-points.nix {src = gtsam-points-src; inherit gtsam_pkg; };
            glim = pkgs.callPackage ./glim.nix {src = glim-src; inherit gtsam_pkg; inherit gtsam-points; };
          in
          {
            packages.mcap = mcap;
            packages.commsdsl = commsdsl;
            packages.commslib = commslib;
            packages.default = flow-ipc;
            packages.foxglove-ws-protocol-cpp = foxglove-ws-protocol-cpp;
            packages.libsocketcanpp = libsocketcanpp;
            packages.dbcppp = dbcppp;
            packages.gtsam_pkg = gtsam_pkg;
            packages.soem = soem;
            packages.glim = glim;
            packages.gtsam-points = gtsam-points;
            overlayAttrs = {
              inherit (config.packages) default commsdsl commslib foxglove-ws-protocol-cpp libsocketcanpp dbcppp mcap gtsam soem glim gtsam-points gtsam_pkg;
            };
            legacyPackages =
              import nixpkgs {
                inherit system;
                overlays = [ self.overlays.default ];
              };
          };
      };
}
