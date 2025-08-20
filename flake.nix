{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    let
      compiler = "ghc984";
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          renameme =
            pkgs.haskell.packages.${compiler}.callPackage ./videoChapter { };
        in
        {
          packages.default = renameme;
          devShells.default = pkgs.mkShell {
            buildInputs =
              with pkgs.haskell.packages."${compiler}"; [
                fourmolu
                cabal-fmt
                implicit-hie
                ghcid
                cabal2nix
                ghc
                pkgs.ghciwatch
                cabal-install
                pkgs.haskell-language-server
              ];
          };
        }) //
    {
      overlays.default = final: prev: {
        videoChapter =
          final.haskell.packages.${compiler}.callPackage ./videoChapter { };
      };
    }
  ;
}
