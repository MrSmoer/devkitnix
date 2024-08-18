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
    flake-utils.lib.eachDefaultSystem(system: 
    let
    pkgs = import nixpkgs {inherit system;};
    imageA64 = pkgs.dockerTools.pullImage {
      imageName = "devkitpro/devkita64";
      imageDigest = "sha256:594b651733c71c0400fef22c513ebbe6a2cbec830286f10f06b3b1b39c74a806";
      sha256 = "9wCDYDprNWAiYq3TKzAef3oac8FXpjlyMlB5VS086Gg=";
      finalImageName = "devkitpro/devkita64";
      finalImageTag = "20240604";
    };
    imageARM = pkgs.dockerTools.pullImage {
      imageName = "devkitpro/devkitarm";
      imageDigest = "sha256:6d86dc5f80c5f9e296521909f36dc5dfd8f4662f3364e746d14a2c3c63282938";
      sha256 = "lrBApLaS7nOaecg2ixxJ1Ghvoqf+nM8dFnQQm6KfDZQ=";
      finalImageName = "devkitpro/devkitarm";
      finalImageTag = "20240511";
    };
    imagePPC = pkgs.dockerTools.pullImage {
      imageName = "devkitpro/devkitppc";
      imageDigest = "sha256:f1eb50b55ac6fc14900a30660b691cdc8e68168302e41370d136d9824913853e";
      sha256 = "Cmd9opj92/yJGJ40rpq3jAmx78wWeL6KAdZcrpJKuKI=";
      finalImageName = "devkitpro/devkitppc";
      finalImageTag = "20240702";
    };
    extractDocker = image:
    pkgs.dockerTools.exportImage {
      name = "dekitpro.tar";
      fromImage = image;
      diskSize = 20 * 1024;

    };
  in {
    packages.devkitA64 = pkgs.stdenv.mkDerivation {
      name = "devkitA64";
      src = extractDocker imageA64;
      sourceRoot = ".";
      nativeBuildInputs = [
        pkgs.autoPatchelfHook
      ];
      buildInputs = [
        pkgs.stdenv.cc.cc
        pkgs.ncurses6
        pkgs.zsnes
        pkgs.gnutar
      ];
      
      buildPhase = "true";
      installPhase = ''
        mkdir -p $out
        #cp -r $src/{devkitA64,libnx,portlibs,tools} $out
        #rm -rf $out/pacman
        cp $src $out
        mkdir $out/nix-support
        echo "export DEVKITPRO=$out" >> $out/nix-support/setup-hook
        echo "export DEVKITA64=$out/devkitA64" >> $out/nix-support/setup-hook
      '';
    };

    packages.devkitARM = pkgs.stdenv.mkDerivation {
      name = "devkitARM";
      nativeBuildInputs = [pkgs.autoPatchelfHook];
      buildInputs = [
        pkgs.stdenv.cc.cc
        pkgs.ncurses6
        pkgs.zsnes
      ];

      src = extractDocker imageARM;
      sourceRoot = ".";
      preUnpack = ''
        tar -xvf $src --strip-components=3 ./opt/devkitpro 
        ls > test
      '';
      buildPhase = "true";
      installPhase = ''
        runHook preInstall
        mkdir -p $out
        ls $src > $out/srclist
        cp -r {devkitARM,libgba,libnds,libctru,libmirko,liborcus,portlibs,tools} $out
        rm -rf $out/pacman
        cp test $out
        mkdir $out/nix-support
        echo "export DEVKITPRO=$out" >> $out/nix-support/setup-hook
        echo "export DEVKITARM=$out/devkitARM" >> $out/nix-support/setup-hook
        runHook postInstall
      '';
    };

    packages.devkitPPC = pkgs.stdenv.mkDerivation {
      name = "devkitPPC";
      src = extractDocker imagePPC;
      sourceRoot = ".";
      nativeBuildInputs = [pkgs.autoPatchelfHook];
      buildInputs = [
        pkgs.stdenv.cc.cc
        pkgs.ncurses6
        pkgs.expat
        pkgs.xz
      ];
      buildPhase = "true";
      installPhase = ''
        mkdir -p $out
        cp -r $src/{devkitPPC,libogc,portlibs,tools,wut} $out
        rm -rf $out/pacman
        mkdir $out/nix-support
        echo "export DEVKITPRO=$out" >> $out/nix-support/setup-hook
        echo "export DEVKITPPC=$out/devkitPPC" >> $out/nix-support/setup-hook
      '';
    };
  });
}
