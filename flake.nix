{
  description = "Helium browser on Nix";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
  };

  outputs =
    { nixpkgs, ... }:
    let
      data = import ./versions.nix;
      version = data.version;
    in
    {
      packages = builtins.mapAttrs (
        system: _:
        let
          arch =
            {
              "x86_64-linux" = "x86_64";
              "aarch64-linux" = "arm64";
            }
            .${system};
          pkgs = nixpkgs.legacyPackages.${system};
          pkg-appimage = pkgs.appimageTools.wrapType2 rec {
            pname = "helium";
            inherit version;

            src = pkgs.fetchurl {
              url = "https://github.com/imputnet/helium-linux/releases/download/${version}/${pname}-${version}-${arch}.AppImage";
              hash = data.appimage.${system};
            };

            extraInstallCommands =
              let
                contents = pkgs.appimageTools.extract { inherit pname version src; };
              in
              ''
                install -m 444 -D ${contents}/${pname}.desktop -t $out/share/applications
                substituteInPlace $out/share/applications/${pname}.desktop \
                  --replace 'Exec=AppRun' 'Exec=${pname}'
                cp -r ${contents}/usr/share/icons $out/share
              '';
          };
        in
        {
          helium-appimage = pkg-appimage;
          default = pkg-appimage;
        }
      ) data.appimage;
    };
}
