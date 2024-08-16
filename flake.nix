{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    pkgs = import nixpkgs {system = "x86_64-linux";};
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
      pkgs.vmTools.runInLinuxVM (
        pkgs.runCommand "docker-preload-image" {
          memSize = 20 * 1024;
          buildInputs = [
            pkgs.curl
            pkgs.kmod
            pkgs.docker
            pkgs.e2fsprogs
            pkgs.utillinux
          ];
        }
        ''
          modprobe overlay

          # from https://github.com/tianon/cgroupfs-mount/blob/master/cgroupfs-mount
          mount -t tmpfs -o uid=0,gid=0,mode=0755 cgroup /sys/fs/cgroup
          cd /sys/fs/cgroup
          for sys in $(awk '!/^#/ { if ($4 == 1) print $1 }' /proc/cgroups); do
            mkdir -p $sys
            if ! mountpoint -q $sys; then
              if ! mount -n -t cgroup -o $sys cgroup $sys; then
                rmdir $sys || true
              fi
            fi
          done

          dockerd -H tcp://127.0.0.1:5555 -H unix:///var/run/docker.sock &

          until $(curl --output /dev/null --silent --connect-timeout 2 http://127.0.0.1:5555); do
            printf '.'
            sleep 1
          done

          echo load image
          docker load -i ${image}

          echo run image
          docker run ${image.destNameTag} tar -C /opt/devkitpro -c . | tar -xv --no-same-owner -C $out || true

          echo end
          kill %1
        ''
      );
  in {
    packages.x86_64-linux.devkitA64 = pkgs.stdenv.mkDerivation {
      name = "devkitA64";
      src = extractDocker imageA64;
      nativeBuildInputs = [
        pkgs.autoPatchelfHook
      ];
      buildInputs = [
        pkgs.stdenv.cc.cc
        pkgs.ncurses6
        pkgs.zsnes
      ];
      buildPhase = "true";
      installPhase = ''
        mkdir -p $out
        cp -r $src/{devkitA64,libnx,portlibs,tools} $out
        rm -rf $out/pacman
        mkdir $out/nix-support
        echo "export DEVKITPRO=$out" >> $out/nix-support/setup-hook
        echo "export DEVKITA64=$out/devkitA64" >> $out/nix-support/setup-hook
      '';
    };

    packages.x86_64-linux.devkitARM = pkgs.stdenv.mkDerivation {
      name = "devkitARM";
      src = extractDocker imageARM;
      nativeBuildInputs = [pkgs.autoPatchelfHook];
      buildInputs = [
        pkgs.stdenv.cc.cc
        pkgs.ncurses6
        pkgs.zsnes
      ];
      buildPhase = "true";
      installPhase = ''
        mkdir -p $out
        cp -r $src/{devkitARM,libgba,libnds,libctru,libmirko,liborcus,portlibs,tools} $out
        rm -rf $out/pacman
        mkdir $out/nix-support
        echo "export DEVKITPRO=$out" >> $out/nix-support/setup-hook
        echo "export DEVKITARM=$out/devkitARM" >> $out/nix-support/setup-hook
      '';
    };

    packages.x86_64-linux.devkitPPC = pkgs.stdenv.mkDerivation {
      name = "devkitPPC";
      src = extractDocker imagePPC;
      nativeBuildInputs = [pkgs.autoPatchelfHook];
      buildInputs = [
        pkgs.stdenv.cc.cc
        pkgs.ncurses5
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
  };
}
