{
  description = "Unity Hub & Unity Editor on NixOS via Distrobox";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      # ── Home-manager module ─────────────────────────────────────
      homeManagerModules = {
        unity = import ./modules/unity.nix;
        # `homeManagerModules.default` allows `inputs.unity.homeManagerModules.default`.
        default = self.homeManagerModules.unity;
      };

      # ── Packages ────────────────────────────────────────────────
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          # Standalone launcher, identical to the one installed by the
          # home-manager module (same script, same pinned runtime).
          unityhub = pkgs.writeShellApplication {
            name = "unityhub";
            runtimeInputs = [
              pkgs.distrobox
              pkgs.podman
            ];
            text = builtins.readFile ./files/launcher.sh;
          };
        }
      );

      # ── Checks ──────────────────────────────────────────────────
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          test = import ./test/eval.nix { inherit nixpkgs home-manager; };
          pkgNames = cfg: builtins.map (p: p.name) cfg.config.home.packages;
        in
        {
          # The module must evaluate and produce a working home environment
          # in both the Distrobox and the native package configurations.
          module-eval-distrobox = pkgs.runCommand "unity-module-eval-distrobox" { } ''
            echo "${builtins.concatStringsSep "\n" (pkgNames test.distrobox)}" > "$out"
            grep -q '^unityhub$' "$out"
            test -f "${test.distrobox.config.xdg.configFile."distrobox/distrobox.ini".source}"
            test -f "${test.distrobox.config.xdg.dataFile."applications/unityhub.desktop".source}"
          '';
          module-eval-native = pkgs.runCommand "unity-module-eval-native" { } ''
            echo "${builtins.concatStringsSep "\n" (pkgNames test.native)}" > "$out"
            grep -q '^unityhub' "$out"
          '';
        }
      );

      # ── Formatter & dev shell ───────────────────────────────────
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = with nixpkgs.legacyPackages.${system}; [
            nixfmt
            shellcheck
          ];
        };
      });
    };
}
