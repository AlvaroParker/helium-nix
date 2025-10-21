# Helium Browser Nix Flake

A Nix flake that packages [Helium](https://github.com/imputnet/helium), a private, fast, and honest web browser.

## Quick Start

### Using with Flakes

Add this flake as an input to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    helium = {
      url = "github:AlvaroParker/helium-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

Then install it in your system configuration:

```nix
environment.systemPackages = [
  inputs.helium.packages.${system}.default
];
```

### Direct Installation

You can also install Helium directly without adding it to your flake inputs:

```bash
# Install to user profile
nix profile install github:AlvaroParker/helium-nix

# Or run directly
nix run github:AlvaroParker/helium-nix
```

### Home Manager

For Home Manager users:

```nix
home.packages = [
  inputs.helium.packages.${pkgs.system}.default
];
```

## Features

- **Automatic Updates**: The flake is automatically updated via GitHub Actions when new Helium releases are available
- **AppImage Packaging**: Uses Nix's `appimageTools` for clean packaging
- **Desktop Integration**: Includes proper desktop entry and icon installation
- **Cross-System**: Works on all systems supported by Nix flakes

## Development

### Building Locally

```bash
# Build the package
nix build

# Run without installing
nix run

# Enter development shell
nix develop
```

## Automated Maintenance

This flake includes automated maintenance via GitHub Actions:

- Hourly checks for new Helium releases
- Automatic version updates and hash recalculation
- Build testing to ensure package integrity
- Automatic commits for successful updates
