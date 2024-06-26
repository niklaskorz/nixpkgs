{
  lib,
  rustPlatform,
  fetchFromGitHub,
  fetchzip,
  copyDesktopItems,
  curl,
  perl,
  pkg-config,
  protobuf,
  xcbuild,
  fontconfig,
  freetype,
  libgit2,
  openssl,
  sqlite,
  zlib,
  zstd,
  alsa-lib,
  libxkbcommon,
  wayland,
  libglvnd,
  xorg,
  stdenv,
  system,
  darwin,
  makeFontsConf,
  vulkan-loader,
  nix-update-script,

  withGLES ? false,
}:

assert withGLES -> stdenv.isLinux;

rustPlatform.buildRustPackage rec {
  pname = "zed";
  version = "0.140.5";

  src = fetchFromGitHub {
    owner = "zed-industries";
    repo = "zed";
    # WIP: https://github.com/zed-industries/zed/pull/13343
    rev = "609b5ae8e429c9286f9a77465ecf5e156ab8fa49";
    hash = "sha256-c3Z0r9AgE+1GYMAwVzZ2suTbyk/yKNc21L9M+z7PvAc=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "alacritty_terminal-0.24.1-dev" = "sha256-aVB1CNOLjNh6AtvdbomODNrk00Md8yz8QzldzvDo1LI=";
      "async-pipe-0.1.3" = "sha256-g120X88HGT8P6GNCrzpS5SutALx5H+45Sf4iSSxzctE=";
      "blade-graphics-0.4.0" = "sha256-fvlHCN1EHbgg+aX7wHf10T+uEealIm9qRFLxgXjJbP8=";
      "cosmic-text-0.11.2" = "sha256-TLPDnqixuW+aPAhiBhSvuZIa69vgV3xLcw32OlkdCcM=";
      "cpal-0.15.3" = "sha256-t+jY+0gygP+4ZHbWc40o2i+A4tLXjwKYEwS6cPvujes=";
      "font-kit-0.11.0" = "sha256-+4zMzjFyMS60HfLMEXGfXqKn6P+pOngLA45udV09DM8=";
      "libwebrtc-0.3.4" = "sha256-2HC5mprs+ub60sRTD1xQIQzQpM5+oEJfspMKngkERNY=";
      "lsp-types-0.95.1" = "sha256-N4MKoU9j1p/Xeowki/+XiNQPwIcTm9DgmfM/Eieq4js=";
      "nvim-rs-0.6.0-pre" = "sha256-bdWWuCsBv01mnPA5e5zRpq48BgOqaqIcAu+b7y1NnM8=";
      "pathfinder_simd-0.5.3" = "sha256-94/qS5d0UKYXAdx+Lswj6clOTuuK2yxqWuhpYZ8x1nI=";
      "tree-sitter-0.20.100" = "sha256-xZDWAjNIhWC2n39H7jJdKDgyE/J6+MAVSa8dHtZ6CLE=";
      "tree-sitter-go-0.20.0" = "sha256-/mE21JSa3LWEiOgYPJcq0FYzTbBuNwp9JdZTZqmDIUU=";
      "tree-sitter-gowork-0.0.1" = "sha256-lM4L4Ap/c8uCr4xUw9+l/vaGb3FxxnuZI0+xKYFDPVg=";
      "tree-sitter-heex-0.0.1" = "sha256-6LREyZhdTDt3YHVRPDyqCaDXqcsPlHOoMFDb2B3+3xM=";
      "tree-sitter-jsdoc-0.20.0" = "sha256-fKscFhgZ/BQnYnE5EwurFZgiE//O0WagRIHVtDyes/Y=";
      "tree-sitter-markdown-0.0.1" = "sha256-F8VVd7yYa4nCrj/HEC13BTC7lkV3XSb2Z3BNi/VfSbs=";
      "tree-sitter-proto-0.0.2" = "sha256-W0diP2ByAXYrc7Mu/sbqST6lgVIyHeSBmH7/y/X3NhU=";
      "xim-0.4.0" = "sha256-vxu3tjkzGeoRUj7vyP0vDGI7fweX8Drgy9hwOUOEQIA=";
    };
  };

  nativeBuildInputs = [
    copyDesktopItems
    curl
    perl
    pkg-config
    protobuf
    rustPlatform.bindgenHook
  ] ++ lib.optionals stdenv.isDarwin [ xcbuild.xcrun ];

  buildInputs =
    [
      curl
      fontconfig
      freetype
      libgit2
      openssl
      sqlite
      zlib
      zstd
    ]
    ++ lib.optionals stdenv.isLinux [
      alsa-lib
      libxkbcommon
      wayland
      xorg.libxcb
    ]
    ++ lib.optionals stdenv.isDarwin (
      with darwin.apple_sdk.frameworks;
      [
        AppKit
        AVFoundation
        CoreAudio
        CoreFoundation
        CoreGraphics
        CoreMedia
        CoreServices
        CoreText
        Foundation
        IOKit
        Metal
        MetalKit
        ScreenCaptureKit #
        Security
        System
        SystemConfiguration
        VideoToolbox
      ]
    );

  # Required on darwin because we don't have access to the
  # proprietary Metal shader compiler.
  buildFeatures = lib.optionals stdenv.isDarwin [ "gpui/runtime_shaders" ];

  env = {
    ZSTD_SYS_USE_PKG_CONFIG = true;
    FONTCONFIG_FILE = makeFontsConf {
      fontDirectories = [
        "${src}/assets/fonts/zed-mono"
        "${src}/assets/fonts/zed-sans"
      ];
    };
  };

  LK_CUSTOM_WEBRTC =
    let
      # Must match WEBRTC_TAG in https://github.com/livekit/rust-sdks/blob/$VERSION/webrtc-sys/build/src/lib.rs
      # where $VERSION is the resolved version of libwebrtc in our ./Cargo.lock
      webrtc_tag = "webrtc-b951613-4";
      webrtc_target = {
        "aarch64-linux" = "linux-arm64";
        "x86_64-linux" = "linux-x64";
        "aarch64-darwin" = "mac-arm64";
        "x86_64-darwin" = "mac-x64";
      }.${system};
    in
    fetchzip {
      url = "https://github.com/livekit/client-sdk-rust/releases/download/${webrtc_tag}/webrtc-${webrtc_target}-release.zip";
      hash = {
        "aarch64-linux" = "sha256-s2bXdOGaTcXN6KI7hMWbV1Q9joGrKSbcrhQlyvRvtVo=";
        "x86_64-linux" = "sha256-F/e6eWvV3R7p0NlfijGBDMmfNpvk3qCcMM8Gf9d5YQ8=";
        "aarch64-darwin" = "sha256-RO15n3TQs0b9tnRdbqF7GoQ9H5orN3IduNBnG+BF3H4=";
        "x86_64-darwin" = "sha256-vLKfw5ZsxhjG+tsw3hUeep2Sb0HaqmajgPkioi5Oyow=";
      }.${system};
    };

  RUSTFLAGS = if withGLES then "--cfg gles" else "";
  gpu-lib = if withGLES then libglvnd else vulkan-loader;

  postFixup = lib.optionalString stdenv.isLinux ''
    patchelf --add-rpath ${gpu-lib}/lib $out/bin/*
    patchelf --add-rpath ${wayland}/lib $out/bin/*
  '';

  checkFlags = lib.optionals stdenv.hostPlatform.isLinux [
    # Fails on certain hosts (including Hydra) for unclear reason
    "--skip=test_open_paths_action"
  ];

  postInstall = ''
    mv $out/bin/Zed $out/bin/zed
    install -D ${src}/crates/zed/resources/app-icon@2x.png $out/share/icons/hicolor/1024x1024@2x/apps/zed.png
    install -D ${src}/crates/zed/resources/app-icon.png $out/share/icons/hicolor/512x512/apps/zed.png
    install -D ${src}/crates/zed/resources/zed.desktop $out/share/applications/dev.zed.Zed.desktop
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--version-regex"
      "v(.*)"
    ];
  };

  meta = with lib; {
    description = "High-performance, multiplayer code editor from the creators of Atom and Tree-sitter";
    homepage = "https://zed.dev";
    changelog = "https://github.com/zed-industries/zed/releases/tag/v${version}";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [
      GaetanLepage
      niklaskorz
    ];
    mainProgram = "zed";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
