{
  description = "Rust dev shell (chill edition)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };

        # wybierz toolchain: stable / nightly / konkretna wersja
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" ];
          # dla WASM dorzuć target:
          # targets = [ "wasm32-unknown-unknown" ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            rustToolchain

            # przydatne narzędzia okołokodowe
            cargo-edit       # cargo add/rm/upgrade
            cargo-watch      # auto-rebuild przy zapisie
            cargo-nextest    # szybszy test runner
            pkg-config

            # gdybyś robił coś z GUI/gamedev (bevy, macroquad itp.)
            # potrzebne libki systemowe na Linuksie:
            alsa-lib
            udev
            vulkan-loader
            libxkbcommon
            wayland
          ];

          # żeby linkowanie działało z dynamicznymi libami (np. bevy)
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.vulkan-loader
            pkgs.libxkbcommon
            pkgs.wayland
          ];

          shellHook = ''
            echo "🦀 Rust dev shell aktywny: $(rustc --version)"

            # RustRover nie ogarnia zmiennych hashy w /nix/store,
            # więc robimy mu stałą ścieżkę przez symlink
            mkdir -p ~/.rust-rover/toolchain
            ln -sfn ${rustToolchain}/lib ~/.rust-rover/toolchain
            ln -sfn ${rustToolchain}/bin ~/.rust-rover/toolchain
            export RUST_SRC_PATH="$HOME/.rust-rover/toolchain/lib/rustlib/src/rust/library"

            # przełącz na zsh, ale tylko raz (żeby nie było pętli)
            if [ -z "$IN_NIX_RUST_SHELL" ]; then
              export IN_NIX_RUST_SHELL=1

              # tymczasowy ZDOTDIR - dopisujemy znacznik do prompta
              # bez ruszania prawdziwego ~/.zshrc (flake zostaje samowystarczalny)
              export OLD_ZDOTDIR="''${ZDOTDIR:-$HOME}"
              export ZDOTDIR=$(mktemp -d)
              cat > "$ZDOTDIR/.zshrc" <<EOF
ZDOTDIR="$OLD_ZDOTDIR"
[ -f "$OLD_ZDOTDIR/.zshrc" ] && source "$OLD_ZDOTDIR/.zshrc"
PROMPT="%F{yellow}(nix-rust)%f \$PROMPT"
EOF

              exec zsh
            fi
          '';
        };
      });
}
