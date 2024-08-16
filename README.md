# devkitnix

Collection of devkitPro packages for Nix using flakes. 

# Changes from upstream
Forked from [github:knarkzel/devkitnix](https://github.com/knarkzel/devkitnix)
- DevkitARM works, I couldn't test devkitA64 and devkitPPC
- Setting the DEVKITPRO and DEVKIT* environment variables automatically
- Used flake-utils to make it work on other platforms as well

```
$ nix flake show github:mrsmoer/devkitnix
└───packages
    └───x86_64-linux
        ├───devkitA64: package 'devkitA64'
        ├───devkitARM: package 'devkitARM'
        └───devkitPPC: package 'devkitPPC'
$ nix build github:mrsmoer/devkitnix#devkitPPC
$ ls result
devkitPPC  libogc  portlibs  tools  wut
```

## Minimal example

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    devkitnix = {
      url = "github:mrsmoer/devkitnix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    devkitnix,
  }: let
    pkgs = import nixpkgs {system = "x86_64-linux";};
    devkitARM = devkitnix.packages.x86_64-linux.devkitARM;
  in {
    devShells.x86_64-linux.default = pkgs.mkShell {
      buildInputs = [
        devkitARM
      ];
    };
  };
}
```

For more example usage of `devkitnix`, see the [Devkitarm example](https://github.com/mrsmoer/Corgi3DS-filetransfer).
Original example was [for switch](ttps://github.com/knarkzel/devkitnix)
