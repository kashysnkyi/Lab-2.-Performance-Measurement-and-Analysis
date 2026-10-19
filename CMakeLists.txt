cmake_minimum_required(VERSION 3.25)
project(PerformanceLab LANGUAGES CXX)

if(NOT MSVC)
    message(FATAL_ERROR "MSVC is required")
endif()

set(CMAKE_CONFIGURATION_TYPES "Release" CACHE STRING "" FORCE)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/assembly")

add_executable(matmul_baseline src/matmul.cpp)
target_compile_definitions(matmul_baseline PRIVATE PROGRAM_VARIANT="baseline")
target_compile_options(matmul_baseline PRIVATE /W4 /Od /Ob0 /Zi /Oy- /FAs "/Fa${CMAKE_BINARY_DIR}/assembly/matmul_baseline.asm")
target_link_options(matmul_baseline PRIVATE /DEBUG)

add_executable(matmul_optimized src/matmul.cpp)
target_compile_definitions(matmul_optimized PRIVATE PROGRAM_VARIANT="optimized" USE_AVX2=1)
target_compile_options(matmul_optimized PRIVATE /W4 /O2 /Ob2 /Oi /Ot /fp:fast /arch:AVX2 /Zi /Oy- /FAs "/Fa${CMAKE_BINARY_DIR}/assembly/matmul_optimized.asm")
target_link_options(matmul_optimized PRIVATE /DEBUG)

set_target_properties(matmul_baseline matmul_optimized PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    PDB_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/pdb")

set_property(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" PROPERTY VS_STARTUP_PROJECT matmul_optimized)

