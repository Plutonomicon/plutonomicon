{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-21.11";
    hercules-ci-effects.url = "github:hercules-ci/hercules-ci-effects";
    flake-compat-ci.url = "github:hercules-ci/flake-compat-ci";
    emanote.url = "github:srid/emanote";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, flake-compat, flake-compat-ci, hercules-ci-effects, emanote, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      hci-effects = hercules-ci-effects.lib.withPkgs pkgs;
    in
    {
      defaultApp.${system} = self.apps.${system}.live;
      defaultPackage.${system} = self.website;
      apps."${system}" = {
        live = rec {
          type = "app";
          # '' is required for escaping ${} in nix
          script = pkgs.writers.writeBash "emanotePlutonomiconLiveReload.sh" ''
            set -xe
            export PORT="''${EMANOTE_PORT:-7071}"
            ${emanote.defaultPackage.${system}}/bin/emanote run  --port $PORT
          '';
          program = builtins.toString script;
        };
      };
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
          ${emanote.defaultPackage.${system}}/bin/emanote \
            --layers "${self};${configDir}" \
            gen $out
        '';
      effects = { src }: {
        gh-pages = hci-effects.runIf (src.ref == "refs/heads/main") (
          hci-effects.mkEffect {
            src = self;
            buildInputs = with pkgs; [ openssh git ];
            secretsMap = {
              "ssh" = "ssh";
            };
            effectScript =
            let
              githubHostKey = "github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==";
            in
            ''
              writeSSHKey
              echo ${githubHostKey} >> ~/.ssh/known_hosts

              export GIT_AUTHOR_NAME="Hercules-CI Effects"
              export GIT_COMMITTER_NAME="Hercules-CI Effects"
              export EMAIL="github@croughan.sh"

              cp -r --no-preserve=mode ${self.website} ./gh-pages && cd gh-pages
              git init -b gh-pages
              git remote add origin git@github.com:Plutonomicon/plutonomicon.git
              git add .
              git commit -m "Deploy to gh-pages"
              git push -f origin gh-pages:gh-pages
            '';
          }
        );
      };
      ciNix = args@{ src }: flake-compat-ci.lib.recurseIntoFlakeWith {
        flake = self;
        systems = [ "x86_64-linux" ];
        effectsArgs = args;
    };
  };
}
