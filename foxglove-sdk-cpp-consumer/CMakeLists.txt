cmake_minimum_required (VERSION 3.15)
project ("foxglove_sdk_consumer" LANGUAGES CXX)

# Everything below is what a downstream user writes. The SDK comes straight out
# of the nix derivation via find_package; nothing is vendored, fetched or built
# from the foxglove tree here.

set (CMAKE_CXX_STANDARD 17)
set (CMAKE_CXX_STANDARD_REQUIRED ON)

find_package (foxglove-sdk REQUIRED)

enable_testing ()

# Both flavours are exercised: linking the C++ wrapper statically (which pulls
# in the Rust staticlib and its platform link libraries transitively) and
# linking it shared (which resolves libfoxglove.so at runtime via RPATH).
add_executable (smoke_shared main.cpp)
target_link_libraries (smoke_shared PRIVATE foxglove-sdk::foxglove_cpp_shared)
add_test (NAME smoke_shared COMMAND smoke_shared)

add_executable (smoke_static main.cpp)
target_link_libraries (smoke_static PRIVATE foxglove-sdk::foxglove_cpp_static)
add_test (NAME smoke_static COMMAND smoke_static)

install (TARGETS smoke_shared smoke_static)
