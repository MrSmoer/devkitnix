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
    inherit (pkgs) dockerTools lib stdenv;


    extractDocker = image: dockerTools.exportImage {
      name = toString (lib.lists.drop 2 (lib.strings.splitString "-" image.tarball));
      fromImage = image.tarball;
      diskSize = image.gigs * 1024;
    };
    dockermappings = {
      devkitA64 = {
        tarball = dockerTools.pullImage {
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
        tarball = dockerTools.pullImage {
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
        tarball = dockerTools.pullImage {
          imageName = "devkitpro/devkitppc";
          imageDigest = "sha256:f1eb50b55ac6fc14900a30660b691cdc8e68168302e41370d136d9824913853e";
          sha256 = "Cmd9opj92/yJGJ40rpq3jAmx78wWeL6KAdZcrpJKuKI=";
          finalImageName = "devkitpro/devkitppc";
          finalImageTag = "20240702";
        };
        gigs = 15;
        targetdirs = [ "devkitPPC" "libogc" "portlibs" "tools" "wut"];
        extraBuildInputs = with pkgs; [ expat ];
      };
    };

    commonMkDerivation = {name}: stdenv.mkDerivation {
      inherit name;
      src = extractDocker (dockermappings.${name});
      nativeBuildInputs = with pkgs; [autoPatchelfHook];
      buildInputs = with pkgs; [
        stdenv.cc.cc
        ncurses6
        zsnes
      ] ++ ( dockermappings.${name}.extraBuildInputs or []);
          
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
        echo "export ${lib.strings.toUpper name}=$out/$name" >> $out/nix-support/setup-hook
        runHook postInstall
      '';
    };

    # borrowed from https://github.com/numtide/flake-utils/blob/b1d9ab70662946ef0850d488da1c9019f3a9752a/lib.nix#L31 
    eachChain = chains: f:
    let
      # Merge together the outputs for all chains.
      op = attrs: chain:
        let
          ret = f chain;
          op = attrs: key: attrs //
              {
                ${key} = (attrs.${key} or { })
                  // { ${chain} = ret.${key}; };
              };
        in
          builtins.foldl' op attrs (builtins.attrNames ret);
    in
      builtins.foldl' op { } chains;

    in (eachChain (builtins.attrNames dockermappings)) ( chain:  
    {
      packages = commonMkDerivation { name = chain; };
    
      devShells = pkgs.mkShell { name = chain; buildInputs = [ self.packages.${system}.${chain} ]; };
    })
  );
}
