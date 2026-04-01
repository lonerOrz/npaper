{
  description = "A Quickshell-based wallpaper selector for Wayland compositors";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    adios-flake.url = "github:Mic92/adios-flake";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    inputs@{
      adios-flake,
      self,
      ...
    }:
    adios-flake.lib.mkFlake {
      inherit inputs self;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      modules = [ ];

      perSystem =
        {
          self',
          pkgs,
          ...
        }:
        let
          lib = pkgs.lib;
          treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs {
            projectRootFile = "flake.nix";
            programs = {
              nixfmt.enable = true;
              shfmt.enable = true;
            };
          };

          runtimeDeps = with pkgs; [
            awww
            wlr-randr
            ffmpeg
            imagemagick
            mpvpaper
          ];

          # Copy source files to store
          npaperSrc = pkgs.runCommand "npaper-src" { } ''
            mkdir -p $out/share/npaper
            cp -r ${./.}/* $out/share/npaper/
          '';

          npaperScript = pkgs.writeShellScriptBin "npaper" ''
            exec ${pkgs.quickshell}/bin/quickshell -p ${npaperSrc}/share/npaper/shell.qml "$@"
          '';

          npaperPackage = pkgs.symlinkJoin {
            name = "npaper";
            paths = [ npaperScript ];
            buildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/npaper \
                --prefix PATH : ${lib.makeBinPath runtimeDeps}
            '';
          };
        in
        {
          formatter = treefmtEval.config.build.wrapper;

          packages = {
            default = self'.packages.npaper;

            npaper = npaperPackage // {
              meta = {
                description = "A Quickshell-based wallpaper selector for Wayland compositors";
                homepage = "https://github.com/lonerOrz/npaper";
                mainProgram = "npaper";
                license = lib.licenses.bsd3;
                maintainers = with lib.maintainers; [ lonerOrz ];
                platforms = [
                  "x86_64-linux"
                  "aarch64-linux"
                ];
              };
            };
          };

          devShells.default = pkgs.mkShell {
            inputsFrom = [ self'.packages.default ];
            packages =
              with pkgs;
              [
                quickshell
              ]
              ++ runtimeDeps;
          };
        };
    };
}
