{
  description = "Melocoton - keyboard-driven, multi-platform database client";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          beamPkgs = pkgs.beam.packages.erlang_27;

          version = "0.22.0";
          pname = "melocoton";
          src = pkgs.lib.cleanSource ./.;

          mixFodDeps = beamPkgs.fetchMixDeps {
            inherit pname version src;
            hash = pkgs.lib.fakeHash;
          };

          nodeDeps = pkgs.buildNpmPackage {
            pname = "${pname}-assets";
            inherit version;
            src = ./assets;
            npmDepsHash = pkgs.lib.fakeHash;
            dontNpmBuild = true;
            installPhase = ''
              mkdir -p $out/node_modules
              cp -r node_modules/. $out/node_modules/
            '';
          };
        in
        {
          default = beamPkgs.mixRelease {
            inherit pname version src mixFodDeps;

            nativeBuildInputs = [
              pkgs.esbuild
              pkgs.tailwindcss
            ];

            BURRITO_WRAP = "false";

            preBuild = ''
              # Link node_modules for JS dependencies (codemirror, etc.)
              ln -sf ${nodeDeps}/node_modules assets/node_modules

              # Point Mix esbuild/tailwind packages to Nix-provided binaries
              export MIX_ESBUILD_PATH="${pkgs.esbuild}/bin/esbuild"
              export MIX_TAILWIND_PATH="${pkgs.tailwindcss}/bin/tailwindcss"
            '';

            postBuild = ''
              # Build assets for production
              mix assets.deploy --no-deps-check
            '';

            meta = with pkgs.lib; {
              description = "Keyboard-driven, multi-platform database client for SQLite and PostgreSQL";
              homepage = "https://github.com/erick/melocoton";
              license = licenses.mit;
              mainProgram = "melocoton";
            };
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          beamPkgs = pkgs.beam.packages.erlang_27;
        in
        {
          default = pkgs.mkShell {
            packages = [
              beamPkgs.erlang
              beamPkgs.elixir
              pkgs.nodejs
              pkgs.esbuild
              pkgs.tailwindcss
              pkgs.sqlite
            ];

            shellHook = ''
              export MIX_HOME="$PWD/.nix-mix"
              export HEX_HOME="$PWD/.nix-hex"
              export PATH="$MIX_HOME/bin:$HEX_HOME/bin:$PATH"
              export LANG="en_US.UTF-8"
              export ERL_AFLAGS="-kernel shell_history enabled"
            '';
          };
        }
      );
    };
}
