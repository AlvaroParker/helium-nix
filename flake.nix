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
      data    = import ./versions.nix;
      version = data.version;
      baseUrl = "https://github.com/imputnet/helium-linux/releases/download/${version}";
    in
    {
      packages = builtins.mapAttrs (
        system: hashes:
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
              url  = "${baseUrl}/${pname}-${version}-${arch}.AppImage";
              hash = hashes.appimage;
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

          pkg-tarball = pkgs.stdenv.mkDerivation rec {
            pname = "helium";
            inherit version;

            src = pkgs.fetchurl {
              url  = "${baseUrl}/${pname}-${version}-${arch}_linux.tar.xz";
              hash = hashes.tarball;
            };

            nativeBuildInputs = with pkgs; [
              autoPatchelfHook
              makeWrapper
              kdePackages.wrapQtAppsHook
            ];

            buildInputs = with pkgs; [
              stdenv.cc.cc.lib
              alsa-lib
              at-spi2-atk
              at-spi2-core
              atk
              cairo
              cups
              dbus
              expat
              glib
              gtk3
              libGL
              libxkbcommon
              mesa
              nspr
              nss
              pango
              udev
              libx11
              libxcb
              libxcomposite
              libxdamage
              libxext
              libxfixes
              libxrandr
              kdePackages.qtbase
              kdePackages.qtwayland
            ];

            autoPatchelfIgnoreMissingDeps = [
              "libQt5Core.so.5"
              "libQt5Gui.so.5"
              "libQt5Widgets.so.5"
            ];

            installPhase = ''
              mkdir -p $out/bin $out/share/applications $out/share/helium
              cp -r . $out/share/helium
              install -m 444 -D ${pname}.desktop $out/share/applications/${pname}.desktop
              substituteInPlace $out/share/applications/${pname}.desktop \
                --replace 'Exec=helium' 'Exec=${pname}'
              makeWrapper $out/share/helium/${pname} $out/bin/${pname} \
                --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [ pkgs.libGL ]}
              mkdir -p $out/share/icons/hicolor/256x256/apps
              ln -s $out/share/helium/product_logo_256.png $out/share/icons/hicolor/256x256/apps/helium.png
            '';
          };
        in
        {
          helium-appimage = pkg-appimage;
          helium-tarball  = pkg-tarball;
          default         = pkg-tarball;
        }
      ) data.systems;
    };
}