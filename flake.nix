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
    pkgs = import nixpkgs { inherit system; };
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

    extractDocker = image: gigs: pkgs.dockerTools.exportImage {
      name = toString (pkgs.lib.lists.drop 2 (pkgs.lib.strings.splitString "-" image));
      #name = "ddd";
      fromImage = image;
      diskSize = gigs * 1024;
    };

    nativeBuildInputs = [pkgs.autoPatchelfHook];
    buildInputs = [
      pkgs.stdenv.cc.cc
      pkgs.ncurses6
      pkgs.zsnes
    ];
    preUnpack = ''
      tar -xvf $src --strip-components=3 ./opt/devkitpro 
    '';
    sourceRoot = ".";
    buildPhase = "true";
    installPhase = ''
      runHook preInstall
      rm -rf $out/pacman
      mkdir $out/nix-support
      echo "export DEVKITPRO=$out" >> $out/nix-support/setup-hook
      runHook postInstall
    '';
    postInstall = ''
      echo "export $uppername=$out/$name" >> $out/nix-support/setup-hook
    '';

  in {
    
    packages.devkitA64 = pkgs.stdenv.mkDerivation(
    let 
      name = "devkitA64"; 
      uppername = pkgs.lib.strings.toUpper name;
    in {
      inherit nativeBuildInputs buildInputs name uppername sourceRoot preUnpack buildPhase installPhase postInstall;
      src = extractDocker imageA64 20;
      
      preInstall = ''
        mkdir -p $out
        cp -r {devkitA64,libnx,portlibs,tools} $out
      '';
    });

    packages.devkitARM = pkgs.stdenv.mkDerivation (
    let
      name = "devkitARM"; 
      uppername = pkgs.lib.strings.toUpper name;
    in {
      inherit buildInputs buildPhase installPhase name nativeBuildInputs preUnpack postInstall sourceRoot uppername;
      src = extractDocker imageARM 10;

      preInstall = ''
        mkdir -p $out
        cp -r {devkitARM,libgba,libnds,libctru,libmirko,liborcus,portlibs,tools} $out
      '';
    });

    packages.devkitPPC = pkgs.stdenv.mkDerivation (
    let 
      name = "devkitPPC";
      uppername = pkgs.lib.strings.toUpper name;
      extendedBuildInputs = buildInputs ++ [ pkgs.expat ];
    in {
    inherit buildPhase installPhase name nativeBuildInputs preUnpack postInstall sourceRoot uppername;
    src = extractDocker imagePPC 20;
    buildInputs = extendedBuildInputs;
    preInstall = ''
      mkdir -p $out
      cp -r {devkitPPC,libogc,portlibs,tools,wut} $out
    '';
    });
  });
}
