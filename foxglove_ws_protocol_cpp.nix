{ src, pkgs, stdenv, cmake, nlohmann_json, websocketpp, boost, zlib, openssl, ... }:
stdenv.mkDerivation {
  pname = "foxglove-ws-protocol-cpp";
  version = "0.0.1";
  src = src+"/cpp/foxglove-websocket";
  nativeBuildInputs = [ cmake ];
  propagatedBuildInputs = [ nlohmann_json websocketpp boost zlib openssl ];
}