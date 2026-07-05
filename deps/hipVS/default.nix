{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  cmake,
  git,
  rocmPackages,
  gtest,
  python3,
  runCommand,
  symlinkJoin,
  blas,
  lapack,
}:
let
  rocwmmaPatched = runCommand "rocwmma-gfx1103" { } ''
    cp -r ${rocmPackages.rocwmma} $out; chmod -R u+w $out
    substituteInPlace $out/include/rocwmma/internal/config.hpp \
      --replace-fail '#elif defined(__gfx1102__) && ROCWMMA_DEVICE_COMPILE
#define ROCWMMA_ARCH_GFX1102 __gfx1102__' '#elif defined(__gfx1102__) && ROCWMMA_DEVICE_COMPILE
#define ROCWMMA_ARCH_GFX1102 __gfx1102__
#elif defined(__gfx1103__) && ROCWMMA_DEVICE_COMPILE
#define ROCWMMA_ARCH_GFX1102 1'
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
      hipblaslt
      hipsparse
      hipsolver
      rocblas
    ]
    ++ [ rocwmmaPatched ];
  };
  rocmdsCmake = fetchFromGitHub {
    owner = "ROCm-DS";
    repo = "ROCmDS-CMake";
    rev = "3d18139480d28a77ea0b2e5980f2d2317a114a91";
    hash = "sha256-V3Z7Zu1zizvMetPveKkQtID95jrJhecGTtCx0K9xwIc=";
  };
  cpmCmake = fetchurl {
    url = "https://github.com/cpm-cmake/CPM.cmake/releases/download/v0.40.0/CPM.cmake";
    hash = "sha256-ezVPOll2xGJsh2hQyTlE5SyD7FmhWa5d5b55g/Dheio=";
  };
  rvsSrc = fetchFromGitHub {
    owner = "ROCm-DS";
    repo = "hipVS";
    rev = "release/rocmds-25.10";
    hash = "sha256-dZVf1vNyrLWJ/NMj7bQqZUQzXxaHX5ugKduGkG7AG3U=";
  };
  fmtSrc = fetchFromGitHub {
    owner = "fmtlib";
    repo = "fmt";
    rev = "11.0.2";
    hash = "sha256-IKNt4xUoVi750zBti5iJJcCk3zivTt7nU12RIf8pM+0=";
  };
  spdlogSrc = fetchFromGitHub {
    owner = "gabime";
    repo = "spdlog";
    rev = "v1.14.1";
    hash = "sha256-F7khXbMilbh5b+eKnzcB0fPPWQqUHqAYPWJb83OnUKQ=";
  };
  libhipcxxSrc = fetchFromGitHub {
    owner = "ROCm";
    repo = "libhipcxx";
    rev = "4d5d918b1f6d85406bc389b8b55be72047228a1c";
    hash = "sha256-ehEQOADZyDSs8S0qITFy4zJB0bO6pw3KAg92Sa7iT00=";
  };
  rmmBase = fetchFromGitHub {
    owner = "ROCm-DS";
    repo = "hipMM";
    rev = "54069b42b6df2418007a72d84ba75db00c56f2bc";
    hash = "sha256-RF6ZZc69vrUxzmYOK08rF8mqkHZxxufyX4f+6zhjtwY=";
  };
  cucoBase = fetchFromGitHub {
    owner = "ROCm";
    repo = "hipCollections";
    rev = "75e15b270bee91b267aee9ba96aa32c3f372960d";
    hash = "sha256-hhD6LOB6yIvhAKQVbKg6CN3rv39SbxLmxlFbWSCqKYQ=";
  };
  cucoSrc = runCommand "hipco-gfx1103" { } ''
    cp -r ${cucoBase} $out; chmod -R u+w $out
    sed -i 's/"gfx1100")/"gfx1100" "gfx1103")/' $out/CMakeLists.txt
  '';
  dlpackSrc = fetchFromGitHub {
    owner = "dmlc";
    repo = "dlpack";
    rev = "v0.8";
    hash = "sha256-IcfCoz3PfDdRetikc2MZM1sJFOyRgKonWMk21HPbrso=";
  };
  hnswlibBase = fetchFromGitHub {
    owner = "nmslib";
    repo = "hnswlib";
    rev = "v0.7.0";
    hash = "sha256-XXz0NIQ5dCGwcX2HtbK5NFTalP0TjLO6ll6TmH3oflI=";
  };
  hnswlibSrc = runCommand "hnswlib-patched" { } ''
    cp -r ${hnswlibBase} $out; chmod -R u+w $out
    ( cd $out && patch -p1 < ${rvsSrc}/cpp/cmake/patches/hnswlib.diff )
  '';
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
  rmmSrc = runCommand "hipmm-with-logger" { } ''
    cp -r ${rmmBase} $out; chmod -R u+w $out
    mkdir -p $out/include/rmm/logger_impl
    sub() { sed -e 's/@_RAPIDS_LOGGER_NAMESPACE@/rmm/g' \
                -e 's/@_RAPIDS_LOGGER_MACRO_PREFIX@/RMM/g' \
                -e 's/@_RAPIDS_LOGGER_DEFAULT_LEVEL@/INFO/g' "$1"; }
    sub ${rocmdsLogger}/logger.hpp.in      > $out/include/rmm/logger.hpp
    sub ${rocmdsLogger}/logger_impl.hpp.in > $out/include/rmm/logger_impl/logger_impl.hpp
    sub ${rocmdsLogger}/logger.cpp.in      > $out/include/rmm/logger_impl/logger.cpp
  '';
in
stdenv.mkDerivation (finalAttrs: {
  pname = "hipvs";
  version = "";

  src = rvsSrc;

  sourceRoot = "${finalAttrs.src.name}/cpp";

  nativeBuildInputs = [
    cmake
    git
    rocmPackages.rocm-cmake
    rocmPackages.clr
  ];

  buildInputs = [
    blas
    lapack
    rocmPackages.clr
    rocmPackages.hipmm
    rocmPackages.rocprim
    rocmPackages.rocsparse
    rocmPackages.rocthrust
    rocmPackages.hipcub
    rocmPackages.hiprand
    rocmPackages.rocrand
    rocmPackages.hipblas
    rocmPackages.hipblas-common
    rocmPackages.hipblaslt
    rocmPackages.hipsparse
    rocmPackages.hipsolver
    rocwmmaPatched
  ];

  cmakeFlags = [
    "-DBUILD_TESTS=OFF"
    "-DBUILD_MG_ALGOS=OFF"
    "-DCMAKE_HIP_ARCHITECTURES=gfx1103"
    "-DUSE_WARPSIZE_32=ON"
    "-DDETECT_CONDA_ENV=OFF"
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    "-DHIP_PATH=${rocmMerged}"
    "-DROCM_PATH=${rocmMerged}"
    "-DCMAKE_HIP_COMPILER_ROCM_ROOT=${rocmMerged}"
    "-DRAPIDS_CMAKE_MODULE_PATH=${rocmdsCmake}/rapids-cmake"
    "-Drapids-cmake-dir=${rocmdsCmake}/rapids-cmake"
    "-DCPM_DOWNLOAD_LOCATION=${cpmCmake}"
    "-DCPM_raft_SOURCE=${raftSrc}"
    "-DFETCHCONTENT_SOURCE_DIR_RAPIDS_LOGGER=${rocmdsLogger}"
    "-DFETCHCONTENT_SOURCE_DIR_FMT=${fmtSrc}"
    "-DFETCHCONTENT_SOURCE_DIR_SPDLOG=${spdlogSrc}"
    "-DFETCHCONTENT_SOURCE_DIR_LIBHIPCXX=${libhipcxxSrc}"
    "-DFETCHCONTENT_SOURCE_DIR_RMM=${rmmSrc}"
    "-DFETCHCONTENT_SOURCE_DIR_CUCO=${cucoSrc}"
    "-DFETCHCONTENT_SOURCE_DIR_DLPACK=${dlpackSrc}"
    "-DFETCHCONTENT_SOURCE_DIR_HNSWLIB=${hnswlibSrc}"
  ];

  postPatch = ''
    export CXX=${rocmPackages.clr}/bin/hipcc
    # Put the merged ROCm include tree on every target's include path so HIP
    # sources find component headers (hiprand, rocrand, ...) that the HIP
    # compiler root alone does not expose. Also override libhipcxx's guard that
    # rejects chrono/timing APIs on the (unofficially supported) gfx1103 arch.
    substituteInPlace CMakeLists.txt \
      --replace-fail 'set(CMAKE_EXPORT_COMPILE_COMMANDS ON)' \
                     'set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
include_directories(SYSTEM ${rocmMerged}/include)
add_compile_definitions(_LIBCUDACXX_ALLOW_UNSUPPORTED_ARCHITECTURE)'
  '';
})
