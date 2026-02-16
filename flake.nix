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

        signal-importer = pkgs.haskell.lib.dontCheck (
          haskellPackages.callCabal2nix "signal-importer" ./. {}
        );

        runtimeWrapper = pkgs.writeShellApplication {
          name = "signal-backup-run";
          runtimeInputs = with pkgs; [
            signalbackup-tools
            sqlite
            postgresql_14
          ];
          text = ''
            set -euo pipefail

            DESKTOP_DIR="''${DESKTOP_DIR:-''${HOME}/Library/Application Support/Signal}"
            DATA_DIR="''${XDG_DATA_HOME:-''${HOME}/.local/share}/signal-backup"
            mkdir -p "''${DATA_DIR}"

            OUT_DB="''${DATA_DIR}/desktop_messages.db"

            # Decide whether to extract or reuse/skip
            if [ "''${SKIP_EXTRACT:-0}" = "1" ]; then
              echo "Skipping extraction (SKIP_EXTRACT=1)"
            else
              if [ -f "''${OUT_DB}" ] && [ "''${OVERWRITE:-0}" != "1" ]; then
                echo "Using existing DB at ''${OUT_DB} (set OVERWRITE=1 to refresh)"
              else
                echo "Extracting Signal Desktop DB from: ''${DESKTOP_DIR}"
                extraFlag=""
                if [ "''${OVERWRITE:-0}" = "1" ]; then extraFlag="--overwrite"; fi
                ${pkgs.signalbackup-tools}/bin/signalbackup-tools \
                  --desktopdir "''${DESKTOP_DIR}" \
                  --dumpdesktopdb "''${OUT_DB}" \
                  "''${extraFlag}"
              fi
            fi

            DB_PATH="''${SIGNAL_DB:-''${OUT_DB}}"
            exec ${signal-importer}/bin/signal-importer \
              --signal-db "''${DB_PATH}" "$@"
          '';
        };

      in {
        packages = {
          default = signal-importer;
          signal-importer = signal-importer;
          signal-backup-run = runtimeWrapper;
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

        apps = {
          default = {
            type = "app";
            program = "${signal-importer}/bin/signal-importer";
          };
          run = {
            type = "app";
            program = "${runtimeWrapper}/bin/signal-backup-run";
          };
        };
      }
    );
}
