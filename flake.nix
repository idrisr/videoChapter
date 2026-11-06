{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachSystem
      [ "x86_64-linux" "aarch64-darwin" ]
      (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          videoChapterRaw =
            pkgs.haskellPackages.callPackage ./videoChapter { };
          videoChapter =
            pkgs.symlinkJoin {
              name = "videoChapter";
              paths = [ videoChapterRaw ];
              nativeBuildInputs = [ pkgs.makeWrapper ];
              postBuild = ''
                wrapProgram "$out/bin/videoChapter" \
                  --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.mediainfo ]}
                mkdir -p "$out/share/zsh/site-functions"
                cp ${./videoChapter/completions/_videoChapter} \
                  "$out/share/zsh/site-functions/_videoChapter"
              '';
            };
        in
        {
          packages.default = videoChapter;
          devShells.default = pkgs.mkShell {
            buildInputs =
              with pkgs.haskellPackages; [
                fourmolu
                cabal-fmt
                implicit-hie
                ghcid
                cabal2nix
                ghc
                pkgs.ghciwatch
                cabal-install
                pkgs.haskell-language-server
                pkgs.mediainfo
                pkgs.zlib
              ];
          };
        }) //
    {
      overlays.default = final: prev: {
        videoChapterRaw =
          final.haskellPackages.callPackage ./videoChapter { };
        videoChapter =
          final.symlinkJoin {
            name = "videoChapter";
            paths = [ final.videoChapterRaw ];
            nativeBuildInputs = [ final.makeWrapper ];
            postBuild = ''
              wrapProgram "$out/bin/videoChapter" \
                --prefix PATH : ${final.lib.makeBinPath [ final.mediainfo ]}
              mkdir -p "$out/share/zsh/site-functions"
              cp ${./videoChapter/completions/_videoChapter} \
                "$out/share/zsh/site-functions/_videoChapter"
            '';
          };
      };
    }
  ;
}
