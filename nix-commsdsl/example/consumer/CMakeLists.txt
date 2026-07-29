cmake_minimum_required (VERSION 3.15)
project ("nebs_demo_consumer" LANGUAGES C CXX)

# Everything below is what a downstream user writes: the packages come straight
# out of the nix-commsdsl derivations, no vendored schemas and no code
# generation in this project.

set (CMAKE_CXX_STANDARD 11)
set (CMAKE_CXX_STANDARD_REQUIRED ON)

find_package (LibComms REQUIRED)
find_package (nebs_demo REQUIRED)
find_package (nebs_demo_c REQUIRED)

enable_testing ()

add_executable (roundtrip_cpp main.cpp)
target_link_libraries (roundtrip_cpp PRIVATE cc::nebs_demo cc::comms)
add_test (NAME roundtrip_cpp COMMAND roundtrip_cpp)

add_executable (roundtrip_c capi.c)
target_link_libraries (roundtrip_c PRIVATE cc::nebs_demo_c)
add_test (NAME roundtrip_c COMMAND roundtrip_c)

install (TARGETS roundtrip_cpp roundtrip_c)
