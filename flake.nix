{
  description = "Signal Desktop message importer for PostgreSQL";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        haskellPackages = pkgs.haskellPackages;

        signal-importer = haskellPackages.callCabal2nix "signal-importer" ./. {};

      in {
        packages = {
          default = signal-importer;
          signal-importer = signal-importer;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Haskell toolchain
            ghc
            cabal-install
            haskell-language-server

            # PostgreSQL
            postgresql_14

            # SQLite
            sqlite

            # Signal backup tools
            signalbackup-tools

            # Development tools
            zlib
            pkg-config
          ];

          # Set up PostgreSQL library paths
          shellHook = ''
            export LD_LIBRARY_PATH="${pkgs.postgresql_14}/lib:$LD_LIBRARY_PATH"
            export PKG_CONFIG_PATH="${pkgs.postgresql_14}/lib/pkgconfig:$PKG_CONFIG_PATH"
            echo "🚀 Signal Importer development environment loaded"
            echo "   - GHC: $(ghc --version)"
            echo "   - Cabal: $(cabal --version | head -1)"
            echo "   - PostgreSQL: $(pg_config --version)"
            echo ""
            echo "Quick start:"
            echo "  cabal build          # Build the project"
            echo "  cabal run signal-importer -- --help"
            echo "  bd list              # View project issues"
          '';
        };

        apps.default = {
          type = "app";
          program = "${signal-importer}/bin/signal-importer";
        };
      }
    );
}
