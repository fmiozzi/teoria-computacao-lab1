{
  description = "Laboratório 1 — Teoria da Computação: Conversão de Autômatos Finitos e Expressões Regulares";

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
          (pkgs.texlive.combine {
            inherit (pkgs.texlive)
              scheme-medium
              abntex2
              enumitem
              ragged2e
              booktabs
              float
              ;
          })
        ];

        shellHook = ''
          echo "Ambiente Haskell + LaTeX/abntex2 carregado"
        '';
      };
    };
}