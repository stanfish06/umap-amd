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
  raftBase = fetchFromGitHub {
    owner = "ROCm-DS";
    repo = "hipRaft";
    rev = "release/rocmds-25.10";
    hash = "sha256-46LOBQAWE0VYz010ShkL4sjBwEDvn89XSsWRHkteFrI=";
  };
  rocmdsCmake = fetchFromGitHub {
    owner = "ROCm-DS";
    repo = "ROCmDS-CMake";
    rev = "3d18139480d28a77ea0b2e5980f2d2317a114a91";
    hash = "sha256-V3Z7Zu1zizvMetPveKkQtID95jrJhecGTtCx0K9xwIc=";
  };
  rocmdsLogger = fetchFromGitHub {
    owner = "ROCm-DS";
    repo = "rocmds-logger";
    rev = "release/rocmds-25.10";
    hash = "sha256-5oYffvjz+pCTZquqcAH/ygc6qXSEyVBB7C1ahs6HwnE=";
  };
  cpmCmake = fetchurl {
    url = "https://github.com/cpm-cmake/CPM.cmake/releases/download/v0.40.0/CPM.cmake";
    hash = "sha256-ezVPOll2xGJsh2hQyTlE5SyD7FmhWa5d5b55g/Dheio=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "hipraft";
  version = "";

  src = raftBase;

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
    rocmPackages.rocprim
    rocmPackages.rocsparse
    rocmPackages.rocthrust
    rocmPackages.hipcub
    rocmPackages.hiprand
    rocmPackages.rocrand
    rocmPackages.hipblas
    rocmPackages.hipblas-common
    rocmPackages.hipsparse
    rocmPackages.hipsolver
  ];

  cmakeFlags = [
    "-DBUILD_TESTS=OFF"
    "-DBUILD_PRIMS_BENCH=OFF"
    "-DCMAKE_HIP_ARCHITECTURES=gfx1103"
    "-DDETECT_CONDA_ENV=OFF"
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    "-DHIP_PATH=${rocmMerged}"
    "-DRAFT_COMPILE_LIBRARY=OFF"
    "-DRAPIDS_CMAKE_MODULE_PATH=${rocmdsCmake}/rapids-cmake"
    "-Drapids-cmake-dir=${rocmdsCmake}/rapids-cmake"
    "-DROCM_PATH=${rocmMerged}"
    "-DCPM_DOWNLOAD_LOCATION=${cpmCmake}"
    "-DFETCHCONTENT_SOURCE_DIR_RAPIDS_LOGGER=${rocmdsLogger}"
  ];

  postPatch = ''
    export CXX=${rocmPackages.clr}/bin/hipcc
  '';
})
