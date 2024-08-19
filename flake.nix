{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
  flake-utils.lib.eachDefaultSystem( system: 
  let
    devkitA64 = "devkitA64";
    devkitARM = "devkitARM";
    devkitPPC = "devkitPPC";

    pkgs = import nixpkgs { inherit system; };

    extractDocker = image: pkgs.dockerTools.exportImage {
      name = toString (pkgs.lib.lists.drop 2 (pkgs.lib.strings.splitString "-" image.tarball));
      fromImage = image.tarball;
      diskSize = image.gigs * 1024;
    };
    dockermappings = {
      devkitA64 = {
        tarball = pkgs.dockerTools.pullImage {
          imageName = "devkitpro/devkita64";
          imageDigest = "sha256:594b651733c71c0400fef22c513ebbe6a2cbec830286f10f06b3b1b39c74a806";
          sha256 = "9wCDYDprNWAiYq3TKzAef3oac8FXpjlyMlB5VS086Gg=";
          finalImageName = "devkitpro/devkita64";
          finalImageTag = "20240604";
        };
        gigs = 15;
        targetdirs = ["devkitA64" "libnx" "portlibs" "tools" ];
      };
      devkitARM = {
        tarball = pkgs.dockerTools.pullImage {
          imageName = "devkitpro/devkitarm";
          imageDigest = "sha256:6d86dc5f80c5f9e296521909f36dc5dfd8f4662f3364e746d14a2c3c63282938";
          sha256 = "lrBApLaS7nOaecg2ixxJ1Ghvoqf+nM8dFnQQm6KfDZQ=";
          finalImageName = "devkitpro/devkitarm";
          finalImageTag = "20240511";
        };
        gigs = 10;
        targetdirs = ["devkitARM" "libgba" "libnds" "libctru" "libmirko" "liborcus" "portlibs" "tools" ];
      };
      devkitPPC = {
        tarball = pkgs.dockerTools.pullImage {
          imageName = "devkitpro/devkitppc";
          imageDigest = "sha256:f1eb50b55ac6fc14900a30660b691cdc8e68168302e41370d136d9824913853e";
          sha256 = "Cmd9opj92/yJGJ40rpq3jAmx78wWeL6KAdZcrpJKuKI=";
          finalImageName = "devkitpro/devkitppc";
          finalImageTag = "20240702";
        };
        gigs = 15;
        targetdirs = [ "devkitPPC" "libogc" "portlibs" "tools" "wut"];
      };
    };

    commonMkDerivation = {name, extraBuildInputs ? [] }: pkgs.stdenv.mkDerivation {
      inherit name;
      src = extractDocker (dockermappings.${name});
      nativeBuildInputs = [pkgs.autoPatchelfHook];
      buildInputs = [
        pkgs.stdenv.cc.cc
        pkgs.ncurses6
        pkgs.zsnes
      ] ++ extraBuildInputs;
          
      preUnpack = ''
        tar -xvf $src --strip-components=3 ./opt/devkitpro 
      '';
      sourceRoot = ".";
      buildPhase = "true";
      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp -r ${builtins.concatStringsSep " " dockermappings.${name}.targetdirs} $out
        rm -rf $out/pacman
        mkdir $out/nix-support
        echo "export DEVKITPRO=$out" >> $out/nix-support/setup-hook
        runHook postInstall
      '';
     
      postInstall = ''
        echo "export ${pkgs.lib.strings.toUpper name}=$out/$name" >> $out/nix-support/setup-hook
      '';
    };
    allChains = [ "devkitA64" "devkitARM" "devkitPPC" ];
  # TODO does the system that is added for impure evaluation have a sideffect? Yes it does, but only if specified --impure
  in (flake-utils.lib.eachSystem allChains) ( chain:  
  {
    packages = commonMkDerivation { name = chain; };
    
    devShells = pkgs.mkShell { name = chain; buildInputs = [ self.packages.${system}.${chain} ]; };
  })
   # TODO this recurses .. yeah I wonder why
   # // {packages.devkitPPC = self.packages.${system}.devkitPPC.overrideAttrs (o: rec {extraBuildInputs = [pkgs.expat];});});
}
