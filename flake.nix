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
      homeModules.unity = import ./modules/unity.nix;
      nixosModules.unity = import ./modules/nixos.nix;

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          tests = import ./test/eval.nix { inherit nixpkgs home-manager; };

          # Assert generated files and the systemd unit are wired up.
          # `extra` adds variant-specific assertions; any failure fails the build.
          mkModuleEval =
            name: test: extra:
            pkgs.runCommand "unity-module-eval-${name}" { } ''
              set -euo pipefail
              echo "${
                builtins.concatStringsSep "\n" (builtins.map (p: p.name) test.config.home.packages)
              }" > "$out"
              grep -q '^unityhub$' "$out"
              test -f "${test.config.xdg.configFile."distrobox/distrobox.ini".source}"
              desktop="${test.config.xdg.dataFile."applications/unityhub.desktop".source}"
              test -f "$desktop"
              grep -q '^Exec=.*systemd-run' "$desktop"
              grep -q '^MimeType=.*x-scheme-handler/unityhub' "$desktop"
              grep -q '^StartupNotify=true' "$desktop"
              test -n "${
                builtins.toString test.config.systemd.user.services."unity-via-distrobox".Service.ExecStart
              }"
              test -n "${
                builtins.toString test.config.systemd.user.services."unity-via-distrobox".Service.ExecStop
              }"
              test -n "${test.config.home.activation.ensureMinimizeToTray.data}"
              ${extra}
              touch "$out"
            '';
        in
        {
          module-eval = mkModuleEval "default" tests.default ''
            echo "${
              builtins.toString tests.default.config.systemd.user.services."unity-via-distrobox".Service.ExecStop
            }" \
              | grep -q 'pkill -TERM unityhub'
          '';
          module-eval-stop-on-exit = mkModuleEval "stop-on-exit" tests.stopOnExit ''
            echo "${
              builtins.toString
                tests.stopOnExit.config.systemd.user.services."unity-via-distrobox".Service.ExecStop
            }" \
              | grep -q 'podman stop unity-via-distrobox'
          '';
          module-eval-minimize-to-tray = mkModuleEval "minimize-to-tray" tests.minimizeToTray ''
            echo "${tests.minimizeToTray.config.home.activation.ensureMinimizeToTray.data}" \
              | grep -q 'ensure-minimize-to-tray.ysh true'
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
