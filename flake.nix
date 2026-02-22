{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      imports = [
        inputs.devshell.flakeModule
        ./nix/modules/devshell.nix
        ./nix/modules/packages.nix
      ];

      flake = {
        nixosModules.happier-server = ./nix/modules/happier-server.nix;
        nixosModules.default = self.nixosModules.happier-server;
      };

      perSystem =
        {
          pkgs,
          lib,
          system,
          ...
        }:
        {
          _module.args.pkgs = import self.inputs.nixpkgs {
            inherit system;
            overlays = [
              # Pin prisma-engines to match the project's @prisma/client version (6.19.2)
              (final: prev: {
                prisma-engines = prev.prisma-engines.overrideAttrs (old: rec {
                  version = "6.19.2";
                  src = final.fetchFromGitHub {
                    owner = "prisma";
                    repo = "prisma-engines";
                    rev = version;
                    hash = "sha256-z3GdnrLEMJIGPKXXbz2wrbiGpuNlgYxqg3iYINYTnPI=";
                  };
                  cargoDeps = final.rustPlatform.fetchCargoVendor {
                    inherit src;
                    pname = "prisma-engines";
                    inherit version;
                    hash = "sha256-PgCfBcmK9RCA5BMacJ5oYEpo2DnBKx2xPbdLb79yCCY=";
                  };
                });
              })
            ];
          };
        };
    };
}
