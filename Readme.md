# Helium browser Nix

```nix
helium = {
  url = "github:AlvaroParker/helium-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Then to install:

```nix
environment.systemPackages = [
  inputs.helium.packages.${system}.default
];
```
