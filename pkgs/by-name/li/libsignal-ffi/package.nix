{ lib, stdenv, fetchFromGitHub, rustPlatform, runCommand, xcodebuild, protobuf, boringssl }:
let
  # boring-sys expects the static libraries in build/ instead of lib/
  boringssl-wrapper = runCommand "boringssl-wrapper" { } ''
    mkdir $out
    cd $out
    cp -r ${boringssl.out}/lib build
    cp -r ${boringssl.dev}/include include
  '';
in
rustPlatform.buildRustPackage rec {
  pname = "libsignal-ffi";
  version = "0.36.1";

  src = fetchFromGitHub {
    owner = "signalapp";
    repo = "libsignal";
    rev = "v${version}";
    hash = "sha256-UD4E2kI1ZNtFhwBGphTzF37NHqbSZjQGHbliOWAMYOE=";
  };

  nativeBuildInputs = [ protobuf ] ++ lib.optionals stdenv.isDarwin [ xcodebuild ];
  buildInputs = [ rustPlatform.bindgenHook ];

  env.BORING_BSSL_PATH = "${boringssl-wrapper}";

  # The Cargo.lock contains git dependencies
  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "boring-3.1.0" = "sha256-R6hh4K57mgV10nuVcMZETvxlQsMsmGapgCQ7pjuognk=";
      "curve25519-dalek-4.1.1" = "sha256-p9Vx0lAaYILypsI4/RVsHZLOqZKaa4Wvf7DanLA38pc=";
    };
  };

  buildPhase = ''
    runHook preBuild
    cargo build --release -p libsignal-ffi
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib
    mv target/release/libsignal_ffi.a $out/lib/
    runHook postInstall
  '';

  meta = with lib; {
    description = "libsignal-ffi is a C ABI library which exposes Signal protocol logic to languages which can consume a C ABI, such as Swift.";
    homepage = "https://github.com/signalapp/libsignal";
    license = licenses.agpl3Plus;
    maintainers = with maintainers; [ niklaskorz ];
  };
}
