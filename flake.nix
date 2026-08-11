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
      nixosModules.unity = import ./modules/nixos.nix;

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
            test -n "${
              builtins.toString test.config.systemd.user.services."unity-via-distrobox".Service.ExecStart
            }"
            test -n "${test.config.home.activation.ensureMinimizeToTray.data}"
          '';
          ysh-syntax = pkgs.runCommand "unity-ysh-syntax" { } ''
            ${pkgs.oils-for-unix}/bin/ysh -n ${./files/unityhub.ysh}
            ${pkgs.oils-for-unix}/bin/ysh -n ${./files/ensure-minimize-to-tray.ysh}
            touch $out
          '';
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
