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
          videoChapterRaw =
            pkgs.haskell.packages.${compiler}.callPackage ./videoChapter { };
          videoChapter =
            pkgs.symlinkJoin {
              name = "videoChapter";
              paths = [ videoChapterRaw ];
              nativeBuildInputs = [ pkgs.makeWrapper ];
              postBuild = ''
                wrapProgram "$out/bin/videoChapter" \
                  --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.mediainfo ]}
              '';
            };
        in
        {
          packages.default = videoChapter;
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
        videoChapterRaw =
          final.haskell.packages.${compiler}.callPackage ./videoChapter { };
        videoChapter =
          final.symlinkJoin {
            name = "videoChapter";
            paths = [ final.videoChapterRaw ];
            nativeBuildInputs = [ final.makeWrapper ];
            postBuild = ''
              wrapProgram "$out/bin/videoChapter" \
                --prefix PATH : ${final.lib.makeBinPath [ final.mediainfo ]}
            '';
          };
      };
    }
  ;
}
