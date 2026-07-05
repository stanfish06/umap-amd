{
  description = "dev shell";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
  };
  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      rocExtraOverlay = final: prev: {
        rocmPackages = prev.rocmPackages.overrideScope (
          rself: rsuper: {
            rocgraph = final.callPackage ./deps/rocGRAPH { };
            hipraft = final.callPackage ./deps/hipRAFT { };
            hipmm = final.callPackage ./deps/hipMM { };
            hipvs = final.callPackage ./deps/hipVS { };
          }
        );
      };
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ rocExtraOverlay ];
      };
    in
    {
      overlays.default = rocExtraOverlay;
      devShells.${system} = {
        default = pkgs.mkShell {
          packages = with pkgs; [
            libtool
            autoconf
            automake
            gfortran
            gnumake
            pkg-config
            cmake
            gcc
            rocmPackages.clr
            # rocmPackages.rocgraph (not needed for now, can explore later, hipgraph also depends on it)
            rocmPackages.hipraft
            rocmPackages.hipmm
            rocmPackages.hipvs
            rocmPackages.rocprim
            rocmPackages.rocsparse
            rocmPackages.rocthrust
            rocmPackages.hipcub
            rocmPackages.hiprand
            rocmPackages.rocrand
          ];
          shellHook = ''
            export DCMAKE_CXX_COMPILER="${pkgs.rocmPackages.clr}/bin/hipcc"
            export DCMAKE_C_COMPILER="${pkgs.rocmPackages.clr}/bin/hipcc"
            export DHIP_PATH="${pkgs.rocmPackages.clr}"
            export DCMAKE_HIP_COMPILER_ROCM_ROOT="${pkgs.rocmPackages.clr}"

            export HIPCC_COMPILE_FLAGS_APPEND="$NIX_CFLAGS_COMPILE \
              -isystem ${pkgs.rocmPackages.hipmm}/include/rapids/libhipcxx \
              -include cstring \
              -DLIBCUDACXX_ENABLE_EXPERIMENTAL_MEMORY_RESOURCE \
              -D_LIBCUDACXX_ALLOW_UNSUPPORTED_ARCHITECTURE \
              -DRAFT_SYSTEM_LITTLE_ENDIAN=1 \
              -DRAFT_LOG_ACTIVE_LEVEL=RAPIDS_LOGGER_LOG_LEVEL_INFO"
          '';
        };
      };
    };
}
