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
      version = "0.9.4.1";

      releases = {
        aarch64-linux = "sha256-BvU0bHtJMd6e09HY+9Vhycr3J0O2hunRJCHXpzKF8lk=";
        x86_64-linux = "sha256-N5gdWuxOrIudJx/4nYo4/SKSxakpTFvL4zzByv6Cnug=";
      };
    in
    {
      packages = builtins.mapAttrs (
        system: hash:
        let
          arch =
            {
              "x86_64-linux" = "x86_64";
              "aarch64-linux" = "arm64";
            }
            .${system};
          pkgs = nixpkgs.legacyPackages.${system};
          pkg = pkgs.appimageTools.wrapType2 rec {
            pname = "helium";
            inherit version;

            src = pkgs.fetchurl {
              url = "https://github.com/imputnet/helium-linux/releases/download/${version}/${pname}-${version}-${arch}.AppImage";
              inherit hash;
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
          helium = pkg;
          default = pkg;
        }
      ) releases;
    };
}
