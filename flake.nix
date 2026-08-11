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
    { nixpkgs, home-manager, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      homeManagerModules.unity = import ./modules/unity.nix;

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          test = import ./test/eval.nix { inherit nixpkgs home-manager; };
          pkgNames = builtins.map (p: p.name) test.config.home.packages;
        in
        {
          module-eval = pkgs.runCommand "unity-module-eval" { } ''
            echo "${builtins.concatStringsSep "\n" pkgNames}" > "$out"
            grep -q '^unityhub$' "$out"
            test -f "${test.config.xdg.configFile."distrobox/distrobox.ini".source}"
            test -f "${test.config.xdg.dataFile."applications/unityhub.desktop".source}"
          '';
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
