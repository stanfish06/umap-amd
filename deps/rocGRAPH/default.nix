{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  rocmPackages,
  gtest,
  python3,
  runCommand,
  symlinkJoin,
}:
let
  fmtSrc = fetchFromGitHub {
    owner = "fmtlib";
    repo = "fmt";
    rev = "11.1.3";
    hash = "sha256-6r9D/csVSgS+T/H0J8cSR+YszxnH/h2V2odi2s6VYN8=";
  };
  spdlogSrc = fetchFromGitHub {
    owner = "gabime";
    repo = "spdlog";
    rev = "v1.15.1";
    hash = "sha256-4QZVCounDbtkP+58fejHGWjquWT3b03b9TNGs45dN7c=";
  };
  stripCM =
    src:
    runCommand "${src.name or "dep"}-nocml" { } ''
      cp -r ${src} $out; chmod -R u+w $out; rm -f $out/CMakeLists.txt
    '';
  libhipcxxSrc = stripCM (fetchFromGitHub {
    owner = "ROCm";
    repo = "libhipcxx";
    rev = "4d5d918b1f6d85406bc389b8b55be72047228a1c";
    hash = "sha256-ehEQOADZyDSs8S0qITFy4zJB0bO6pw3KAg92Sa7iT00=";
  });
  rmmSrc = stripCM (fetchFromGitHub {
    owner = "ROCm-DS";
    repo = "hipMM";
    rev = "2ac101db677413fa974efc47e48226fd52cce218";
    hash = "sha256-EYVS0GJtbSF+bPYuo6Pa1kErA8+BIkuJKPXchhHxr1U=";
  });
  cucoSrc = stripCM (fetchFromGitHub {
    owner = "ROCm";
    repo = "hipCollections";
    rev = "75e15b270bee91b267aee9ba96aa32c3f372960d";
    hash = "sha256-hhD6LOB6yIvhAKQVbKg6CN3rv39SbxLmxlFbWSCqKYQ=";
  });
  raftBase = fetchFromGitHub {
    owner = "ROCm-DS";
    repo = "hipRaft";
    rev = "release/rocmds-25.10";
    hash = "sha256-46LOBQAWE0VYz010ShkL4sjBwEDvn89XSsWRHkteFrI=";
  };
  rocmdsLogger = fetchFromGitHub {
    owner = "ROCm-DS";
    repo = "rocmds-logger";
    rev = "release/rocmds-25.10";
    hash = "sha256-5oYffvjz+pCTZquqcAH/ygc6qXSEyVBB7C1ahs6HwnE=";
  };
  raftSrc = runCommand "hipraft-with-logger" { } ''
    cp -r ${raftBase} $out; chmod -R u+w $out
    mkdir -p $out/cpp/include/raft/core/logger_impl
    sub() { sed -e 's/@_RAPIDS_LOGGER_NAMESPACE@/raft/g' \
                -e 's/@_RAPIDS_LOGGER_MACRO_PREFIX@/RAFT/g' \
                -e 's/@_RAPIDS_LOGGER_DEFAULT_LEVEL@/INFO/g' "$1"; }
    sub ${rocmdsLogger}/logger.hpp.in      > $out/cpp/include/raft/core/logger.hpp
    sub ${rocmdsLogger}/logger_impl.hpp.in > $out/cpp/include/raft/core/logger_impl/logger_impl.hpp
    sub ${rocmdsLogger}/logger.cpp.in      > $out/cpp/include/raft/core/logger_impl/logger.cpp
  '';
  rocmMerged = symlinkJoin {
    name = "rocm-merged-for-raft";
    paths = with rocmPackages; [
      clr
      rocprim
      rocsparse
      rocthrust
      hipcub
      hiprand
      rocrand
      hipblas
      hipblas-common
      hipsparse
      hipsolver
      rocblas
    ];
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "rocgraph";
  version = "7.0.2";

  src = fetchFromGitHub {
    owner = "ROCm-DS";
    repo = "rocGRAPH";
    rev = "9916ad70792a39c793e53e6e81debbc802786a48";
    hash = "sha256-BzAUJgglAgXEyTiZqU2JaGygYP8TF/CoHHyPnFm+2FY=";
  };

  nativeBuildInputs = [
    cmake
    rocmPackages.rocm-cmake
    rocmPackages.clr
  ];

  buildInputs = with rocmPackages; [
    clr
    rocprim
    rocsparse
    rocthrust
    hipcub
    hiprand
    rocrand
    hipblas
    hipblas-common
    hipsparse
    hipsolver
  ];

  cmakeFlags = [
    "-DCMAKE_HIP_COMPILER_ROCM_ROOT=${rocmPackages.clr}"
    "-DBUILD_CLIENTS_TESTS=OFF"
    "-DBUILD_CLIENTS_SAMPLES=OFF"
    "-DAMDGPU_TARGETS=gfx1103"
    "-DGPU_TARGETS=gfx1103"
    "-DFETCHCONTENT_SOURCE_DIR_FMT=${fmtSrc}"
    "-DFETCHCONTENT_SOURCE_DIR_SPDLOG=${spdlogSrc}"
    "-DFETCHCONTENT_SOURCE_DIR_LIBHIPCXX=${libhipcxxSrc}"
    "-DFETCHCONTENT_SOURCE_DIR_RMM=${rmmSrc}"
    "-DFETCHCONTENT_SOURCE_DIR_CUCO=${cucoSrc}"
    "-DOVERRIDE_RAFT_SOURCE_DIR=${raftSrc}"
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    "-DROCM_PATH=${rocmMerged}"
    "-DHIP_PATH=${rocmMerged}"
    "-DCMAKE_HIP_COMPILER_ROCM_ROOT=${rocmMerged}"
  ];

  postPatch = ''
        cp LICENSE LICENSE.md
        cp ${raftSrc}/cpp/include/raft/core/logger_impl/logger.cpp \
           library/src/raft_logger_impl.cpp
        cat >> library/CMakeLists.txt <<EOF
    target_sources(rocgraph PRIVATE \''${CMAKE_CURRENT_SOURCE_DIR}/src/raft_logger_impl.cpp)
    target_include_directories(rocgraph SYSTEM PRIVATE ${rocmMerged}/include)
    EOF
        substituteInPlace library/include/cpp/utilities/device_properties.hpp \
          --replace-fail "int inline constexpr warp_size()" \
                         "int inline warp_size()"
        export CXX=${rocmPackages.clr}/bin/hipcc
  '';
})
