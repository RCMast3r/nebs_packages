{ lib
, stdenv
, fetchFromGitHub
, cmake
, perl
, patchelf
, rustPlatform
, libwebsockets
, nlohmann_json
, catch2_3
  # Remote access pulls in LiveKit/WebRTC and only produces a cdylib. Off by
  # default: it roughly triples the Rust build and drags in a webrtc-sys build.
, remoteAccess ? false
}:

let
  version = "0.27.0";

  src = fetchFromGitHub {
    owner = "foxglove";
    repo = "foxglove-sdk";
    rev = "sdk/v${version}";
    hash = "sha256-fitADcR8yXHpAwe0dnbrRGO4JTytkcyvWkisBpWBciU=";
  };

  # Header-only, not in nixpkgs. Pinned to the exact commit that
  # cpp/CMakeLists.txt's FetchContent_Declare asks for. Fed back to CMake via
  # FETCHCONTENT_SOURCE_DIR_BASE64 so FetchContent never touches the network.
  base64-src = fetchFromGitHub {
    owner = "tobiaslocker";
    repo = "base64";
    rev = "8d96a2a737ac1396304b1de289beb3a5ea0cb752";
    hash = "sha256-wIKw70H42UuKbQGUmclG0XQVgVB1WODr2WCyBBYQeQ4=";
  };

  # The Rust half of the SDK (crate `foxglove_c`), compiled from source into
  # libfoxglove.{a,so}. Upstream drives this through corrosion, which shells out
  # to cargo mid-CMake and wants crates.io at build time; instead we build it
  # here with a vendored registry and hand the artifacts to CMake via
  # FOXGLOVE_PREBUILT_LIB_DIR. Nothing prebuilt by Foxglove is redistributed.
  foxglove-c = rustPlatform.buildRustPackage {
    pname = "foxglove-c";
    inherit version src;

    cargoHash = "sha256-g/S8hbRaQZbMwxV1fYBTwfjzUtjTO8lyk6PJigPKs1o=";

    # The workspace also holds the Python bindings and assorted example crates;
    # only foxglove_c is wanted here.
    cargoBuildFlags = [ "--package" "foxglove_c" ]
      ++ lib.optionals remoteAccess [ "--features" "remote-access" ];

    # aws-lc-sys (the default rustls crypto backend, per upstream's `full`
    # feature set) builds its C sources through cmake and generates a little
    # perl-driven asm. cmake is a build tool for the crate here, not for this
    # derivation, so its configure hook has to stay out of the way.
    nativeBuildInputs = [ cmake perl ];
    dontUseCmakeConfigure = true;

    # Rust-side tests belong to the upstream workspace CI, not to packaging.
    doCheck = false;

    # buildRustPackage's install hook only knows about bins; this crate is
    # staticlib + cdylib. The target dir is layered differently depending on
    # whether cargo was given --target, so just locate the artifacts.
    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib" "$out/include"

      found=0
      for f in $(find target -name 'libfoxglove.a' -o -name 'libfoxglove.so' -o -name 'libfoxglove.dylib'); do
        install -Dm644 "$f" "$out/lib/$(basename "$f")"
        found=1
      done
      if [ "$found" != 1 ]; then
        echo "no libfoxglove artifacts found under target/" >&2
        exit 1
      fi

      # cbindgen regenerates this during build.rs; ship it next to the libs so
      # the C++ build and the installed package both see the matching header.
      cp -r c/include/. "$out/include/"

      runHook postInstall
    '';

    meta = {
      description = "C ABI shared/static library underlying the Foxglove C++ SDK";
      homepage = "https://github.com/foxglove/foxglove-sdk";
      license = lib.licenses.mit;
      platforms = lib.platforms.unix;
    };
  };

in
stdenv.mkDerivation {
  pname = "foxglove-sdk-cpp";
  inherit version src;

  # The C++ build lives in cpp/ but reaches up into ../c/include, so the whole
  # repo has to be unpacked and cmake pointed at the subdirectory.
  cmakeDir = "../cpp";

  nativeBuildInputs = [ cmake ] ++ lib.optional stdenv.hostPlatform.isLinux patchelf;

  buildInputs = [
    libwebsockets
    nlohmann_json
    catch2_3
  ];

  cmakeFlags = [
    # nixpkgs' cmake hook defaults these to absolute paths ($out/lib, ...) to
    # support multiple outputs. Upstream's foxglove-sdkConfig.cmake.in builds
    # its library paths as "${PACKAGE_PREFIX_DIR}/@CMAKE_INSTALL_LIBDIR@",
    # which with an absolute LIBDIR yields "$out//nix/store/...". Those paths
    # fail the EXISTS check in foxglove_sdk_import_c_libs, the foxglove-static
    # and foxglove-shared IMPORTED targets are silently never created, and
    # downstream links degrade to a bare -lfoxglove-static. Keep them relative;
    # this derivation is single-output anyway.
    (lib.cmakeFeature "CMAKE_INSTALL_LIBDIR" "lib")
    (lib.cmakeFeature "CMAKE_INSTALL_BINDIR" "bin")
    (lib.cmakeFeature "CMAKE_INSTALL_INCLUDEDIR" "include")
    (lib.cmakeBool "USE_PACKAGE_MANAGER_DEPENDENCIES" true)
    (lib.cmakeBool "FOXGLOVE_BUILD_EXAMPLES" false)
    (lib.cmakeBool "FOXGLOVE_REMOTE_ACCESS" remoteAccess)
    # Upstream's escape hatch from corrosion: import libfoxglove.{a,so} from
    # disk instead of invoking cargo from inside the CMake build.
    (lib.cmakeFeature "FOXGLOVE_PREBUILT_LIB_DIR" "${foxglove-c}/lib")
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_BASE64" "${base64-src}")
    # -Werror against a compiler this code wasn't pinned to is a packaging
    # hazard, not a useful signal.
    (lib.cmakeBool "STRICT" false)
  ];

  doCheck = true;
  checkTarget = "test";

  # foxglove_cpp_shared carries INSTALL_RPATH "$ORIGIN" to find libfoxglove.so
  # beside it. patchELF's --allowed-rpath-prefixes pass drops non-store entries,
  # so restate the dependency as an absolute store path after fixup.
  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    patchelf --add-rpath "$out/lib" "$out/lib/libfoxglove_cpp_shared.so"
  '';

  passthru = {
    inherit foxglove-c;
  };

  meta = {
    description = "Foxglove SDK for C++, built from source with a CMake package config";
    homepage = "https://github.com/foxglove/foxglove-sdk";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
