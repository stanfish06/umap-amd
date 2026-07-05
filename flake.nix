{
  description = "dev shell";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
  };
  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      rocgraphOverlay = final: prev: {
        rocmPackages = prev.rocmPackages.overrideScope (
          rself: rsuper: {
            rocgraph = final.callPackage ./deps/rocGRAPH { };
          }
        );
      };
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ rocgraphOverlay ];
      };
    in
    {
      overlays.default = rocgraphOverlay;
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
            rocmPackages.rocgraph
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
          '';
        };
      };
    };
}
