{
  description = "Resonara Freeverb native CLAP development";
  nixConfig = {
    extra-substituters = [ "https://scarlet-rust-toolchain.cachix.org" ];
    extra-trusted-public-keys = [ "scarlet-rust-toolchain.cachix.org-1:p+coBExi0nNTIvWF/oM9H9/1/GhwFtqGZ2Vs+4pYl6o=" ];
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/3e41b24abd260e8f71dbe2f5737d24122f972158";
    scarlet-rust-toolchain.url = "github:petitstrawberry/scarlet-rust-nix/ecd6c50a4760279fa10f7a80e56e33dda46c89e0";
  };
  outputs = { nixpkgs, scarlet-rust-toolchain, ... }: let
    systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
  in {
    devShells = forAllSystems (system: let
      pkgs = import nixpkgs { inherit system; };
      rust = scarlet-rust-toolchain.packages.${system}.scarlet-rust-toolchain;
      common = [ pkgs.python3 pkgs.llvmPackages.bintools pkgs.rustfmt ];
    in {
      default = pkgs.mkShell {
        packages = [ rust ] ++ common;
        CARGO_BUILD_JOBS = "2";
        shellHook = "export PATH=${rust}/bin:$PATH";
      };
      host = pkgs.mkShell {
        packages = [ pkgs.rustc pkgs.cargo ] ++ common
          ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.pkg-config pkgs.fontconfig ];
      };
    });
  };
}
