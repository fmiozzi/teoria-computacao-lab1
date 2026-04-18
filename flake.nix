{
  description = "Lab 1 - Haskell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11"; # versão fixa = reprodutibilidade
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          pkgs.haskell.compiler.ghc94
          pkgs.cabal-install
        ];

        shellHook = ''
          echo "Ambiente Haskell carregado (GHC + Cabal)"
        '';
      };
    };
}