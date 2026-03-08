{
  lib,
  stdenv,
  fetchFromGitHub,
  makeBinaryWrapper,
  nodejs,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_11,
  electron_44,
  rustPlatform,
  cargo,
  rustc,
  python3,
  autoPatchelfHook,
  cctools,
  libx11,
  libxrandr,
  libxtst,
  libxt,
}:

let
  pnpm = pnpm_11;
  electron = electron_44;
  distSuffix = lib.optionalString stdenv.hostPlatform.isAarch64 "-arm64";
  # must match between Electron metadata name, desktop file and icons
  appId = "app.fluxer.Fluxer";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "fluxer-desktop";
  version = "2026.1006.171735";

  strictDeps = true;
  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "fluxerapp";
    repo = "fluxer";
    tag = "fluxer-desktop-stable@${finalAttrs.version}";
    hash = "sha256-ivbVYCNRwTfGRiVEVz8nESlols9liHxZLmT/3j/NR7s=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 4;
    hash = "sha256-ZZURJZztdxfJGG/JR8Eawss1dyaIrueWIbCJ97h7Rlo=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname version src;
    hash = "sha256-HMAOhX+9qX/v36/p6TWgZuyZeiKrjsKWF3beXe1ejoU=";
  };

  nativeBuildInputs = [
    makeBinaryWrapper
    nodejs
    pnpmConfigHook
    pnpm
    rustPlatform.cargoSetupHook
    cargo
    rustc
    python3
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    cctools
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    # required by uiohook-napi
    (lib.getLib stdenv.cc.cc) # libgcc_s.so.1, libstdc++.so.6
    libx11
    libxrandr
    libxtst
    libxt
  ];

  env.NODE_ENV = "production";

  preConfigure = ''
    cd fluxer_desktop
  '';

  buildPhase = ''
    runHook preBuild

    pnpm build

    # Needs to be writable
    cp -r ${electron.dist} electron-dist
    chmod -R u+w electron-dist

    export npm_config_nodedir=${electron.headers}
    pnpm exec electron-builder \
      --config electron-builder.config.cjs \
      --dir \
      -c.electronDist=electron-dist \
      -c.electronVersion=${electron.version} \
      -c.extraMetadata.name=${appId} \
      -c.extraMetadata.version=${finalAttrs.version} \
      -c.mac.identity=null

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    mkdir -p $out/share/{applications,metainfo,${appId}}
    mkdir -p $out/bin

    cp -r ./dist-electron/linux${distSuffix}-unpacked/resources/* $out/share/${appId}

    makeWrapper ${lib.getExe electron} $out/bin/fluxer-desktop \
      --add-flags "$out/share/${appId}/app.asar"

    substitute {packaging/linux,$out/share/applications}/${appId}.desktop \
      --replace-fail "Exec=${appId}" "Exec=$out/bin/fluxer-desktop"

    install -Dm444 packaging/linux/${appId}.metainfo.xml $out/share/metainfo/

    mkdir -p $out/share/icons/hicolor/scalable/apps
    install -Dm444 packaging/linux/${appId}.svg $out/share/icons/hicolor/scalable/apps/
  ''
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    mkdir -p $out/{bin,Applications}
    mv dist-electron/mac${distSuffix}/Fluxer.app $out/Applications/

    # Allow launching the app through a shell (e.g., with `nix run`)
    cat << EOF > "$out/bin/fluxer-desktop"
    #!${stdenv.shell}
    open -na "$out/Applications/Fluxer.app" --args "\$@"
    EOF
    chmod +x "$out/bin/fluxer-desktop"
  ''
  + ''
    runHook postInstall
  '';

  meta = {
    description = "Free and open source instant messaging and VoIP platform built for friends, groups, and communities";
    homepage = "https://fluxer.app/";
    mainProgram = "fluxer-desktop";
    license = lib.licenses.agpl3Plus;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    maintainers = with lib.maintainers; [
      niklaskorz
    ];
  };
})
