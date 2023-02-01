{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    emanote.url = "github:srid/emanote";

    hercules-ci-effects.url = "github:hercules-ci/hercules-ci-effects";
    flake-parts.follows = "hercules-ci-effects/flake-parts";

    flake-compat-ci.url = "github:hercules-ci/flake-compat-ci";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = inputs @ { self, flake-parts, hercules-ci-effects, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } ({ ... }: {
      imports = [
        hercules-ci-effects.flakeModule
      ];

      systems = [ "x86_64-linux" ];

      # { self, hercules-ci-effects, emanote, nixpkgs }
      perSystem = { self', inputs', pkgs, system, ... }:
        let
          emanote = inputs.emanote.defaultPackage.${system};
        in
        {
          apps = {
            default = self'.apps.live;
            live =
              let
                script = pkgs.writers.writeBash "emanotePlutonomiconLiveReload.sh" ''
                  set -xe
                  export PORT="''${EMANOTE_PORT:-7071}"
                  ${emanote}/bin/emanote run  --port $PORT
                '';
              in
              {
                type = "app";
                program = script.outPath;
              };
          };

          packages = {
            default = self'.packages.website;
            website =
              let
                configFile = (pkgs.formats.yaml {}).generate "plutonomicon-configFile" {
                  template.baseUrl = "/plutonomicon/";
                };
                configDir = pkgs.runCommand "plutonomicon-configDir" {} ''
                  mkdir -p $out
                  cp ${configFile} $out/index.yaml
                '';
              in
              pkgs.runCommand "plutonomicon-website" {}
              ''
                mkdir $out
                ${emanote}/bin/emanote \
                  --layers "${self};${configDir}" \
                  gen $out
              '';
          };

          hercules-ci.github-pages.settings.contents = self'.packages.website;
        };

      hercules-ci.github-pages.branch = "main";

      herculesCI.ciSystems = [ "x86_64-linux" ];
    });
}
