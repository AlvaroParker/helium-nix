# Helium Browser Nix Flake

A Nix flake that packages [Helium](https://github.com/imputnet/helium), a private, fast, and honest web browser.

## Fork details

* Forked from [AlvaroParker/helium-nix](https://github.com/AlvaroParker/helium-nix) by [x13-me](https://github.com/x13-me/), to add support for aarch64.

* Refactored to remove AppImage dependency

* Workflow refactored to handle errors better, manual build verification can now be run

[![main](https://github.com/x13-me/helium-nix/actions/workflows/update-helium.yml/badge.svg)](https://github.com/x13-me/helium-nix/actions/workflows/update-helium.yml)
`main` branch tracks `latest` tag, use this for `release` builds
[![rolling](https://github.com/x13-me/helium-nix/actions/workflows/update-helium.yml/badge.svg?branch=rolling)](https://github.com/x13-me/helium-nix/actions/workflows/update-helium.yml)
`rolling` branch tracks releases, use this for `pre-release` builds


Flake outputs, for both arch:

```elixir
├───default -> tarball
├───helium-appimage - AlvaroParker  - AppImage wrapper
└───helium-tarball  - x13-me  - Binary Tarball wrapper
```

## Quick Start

### Using with Flakes

Add this flake as an input to your `flake.nix`:

```nix
{
  inputs = {
    helium = {
      url = "github:x13-me/helium-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

Then install it in your system configuration:

```nix
{
  environment.systemPackages = [
    inputs.helium.packages.${system}.default
  ];
}
```

### Direct Installation

You can also install Helium directly without adding it to your flake inputs:

```bash
# Install to user profile
nix profile install github:x13-me/helium-nix

# Or run directly
nix run github:x13-me/helium-nix
```

### Home Manager

For Home Manager users:

```nix
{
  home.packages = [
    inputs.helium.packages.${pkgs.system}.default
  ];
}
```

## Features

- **Automatic Updates**: The flake is automatically updated via GitHub Actions when new Helium releases are available
- **Binary Tarball Packaging**: No AppImage dependency
- **Desktop Integration**: Includes proper desktop entry and icon installation
- **Cross-System**: Works on `x86_64-linux` **and** `aarch64-linux`!

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
