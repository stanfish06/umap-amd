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
}:
let
  rocmMerged = symlinkJoin {
    name = "rocm-merged-for-raft";
    paths = with rocmPackages; [
      clr
      rocprim
      rocthrust
      hipcub
    ];
  };
  rmmSrc = fetchFromGitHub {
    owner = "ROCm-DS";
    repo = "hipMM";
    rev = "54069b42b6df2418007a72d84ba75db00c56f2bc";
    hash = "sha256-RF6ZZc69vrUxzmYOK08rF8mqkHZxxufyX4f+6zhjtwY=";
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
  libhipcxxSrc = fetchFromGitHub {
    owner = "ROCm";
    repo = "libhipcxx";
    rev = "9ac637b66019a8fcf6796f8cfd7b2c13f76313b6";
    hash = "sha256-PRt+YdejdeqLDbYSrRrId6tMWDzW1+EaabWxqmnzxjM=";
  };
  cpmCmake = fetchurl {
    url = "https://github.com/cpm-cmake/CPM.cmake/releases/download/v0.40.0/CPM.cmake";
    hash = "sha256-ezVPOll2xGJsh2hQyTlE5SyD7FmhWa5d5b55g/Dheio=";
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
in
stdenv.mkDerivation (finalAttrs: {
  pname = "hipmm";
  version = "3.0.0";

  src = rmmSrc;

  nativeBuildInputs = [
    cmake
    git
    rocmPackages.rocm-cmake
    rocmPackages.clr
  ];

  buildInputs = [
    rocmPackages.clr
    rocmPackages.rocprim
    rocmPackages.rocthrust
    rocmPackages.hipcub
  ];

  cmakeFlags = [
    "-DBUILD_TESTS=OFF"
    "-DBUILD_PRIMS_BENCH=OFF"
    "-DCMAKE_HIP_ARCHITECTURES=gfx1103"
    "-DDETECT_CONDA_ENV=OFF"
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    "-DHIP_PATH=${rocmMerged}"
    "-DROCM_PATH=${rocmMerged}"
    "-DRAPIDS_CMAKE_MODULE_PATH=${rocmdsCmake}/rapids-cmake"
    "-Drapids-cmake-dir=${rocmdsCmake}/rapids-cmake"
    "-DCPM_DOWNLOAD_LOCATION=${cpmCmake}"
    "-DFETCHCONTENT_SOURCE_DIR_RAPIDS_LOGGER=${rocmdsLogger}"
    "-DFETCHCONTENT_SOURCE_DIR_LIBHIPCXX=${libhipcxxSrc}"
    "-DFETCHCONTENT_SOURCE_DIR_FMT=${fmtSrc}"
    "-DFETCHCONTENT_SOURCE_DIR_SPDLOG=${spdlogSrc}"
  ];

  postPatch = ''
    export CXX=${rocmPackages.clr}/bin/hipcc
  '';
})
