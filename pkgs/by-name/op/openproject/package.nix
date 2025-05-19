{
  lib,
  stdenv,
  applyPatches,
  fetchFromGitHub,
  bundlerEnv,
  ruby_3_4,
  fetchNpmDeps,
  nodejs,
  npmHooks,
  python3,
  cctools,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "openproject";
  version = "15.5.1";

  src = applyPatches {
    src = fetchFromGitHub {
      owner = "opf";
      repo = "openproject";
      tag = "v${finalAttrs.version}";
      hash = "sha256-WdsZWhr2kQM4bMvHl2LafS/S0TKA9UaYhFqQZt9p9rA=";
    };

    postPatch = ''
      sed -i -e "s|ruby '3.4.[0-9]\+'|ruby '${ruby_3_4.version}'|" Gemfile
      sed -i -e "s|ruby 3.4.[0-9]\+p[0-9]\+|ruby ${ruby_3_4.version}|" Gemfile.lock
      sed -i -e "s|3.4.[0-9]\+|${ruby_3_4.version}|" .ruby-version
    '';
  };

  gems = bundlerEnv {
    inherit (finalAttrs) version;
    ruby = ruby_3_4;
    name = "${finalAttrs.pname}-gems-${finalAttrs.version}";
    gemdir = finalAttrs.src;
    extraConfigPaths = [
      "${finalAttrs.src}/.ruby-version"
      "${finalAttrs.src}/Gemfile.modules"
      "${finalAttrs.src}/modules"
    ];
    gemset = import ./gemset.nix finalAttrs.src;
  };

  frontend = stdenv.mkDerivation {
    inherit (finalAttrs) version src;
    pname = "${finalAttrs.pname}-frontend";

    npmDeps = fetchNpmDeps {
      src = "${finalAttrs.src}/frontend";
      hash = "sha256-HKDkYEHVYQnIlmYA1L1RYRPnvJqZ6D8Fp4dvzGiWma8=";
    };

    npmRoot = "frontend";

    nativeBuildInputs =
      [
        finalAttrs.gems
        finalAttrs.gems.wrappedRuby
        nodejs
        npmHooks.npmConfigHook
        python3
      ]
      ++ lib.optionals stdenv.buildPlatform.isDarwin [
        cctools
      ];

    env = {
      RAILS_ENV = "production";
      NODE_ENV = "production";
      SECRET_KEY_BASE = "1";
      DATABASE_URL = "nulldb://db";
    };

    buildPhase = ''
      runHook preBuild

      bin/rails openproject:plugins:register_frontend assets:precompile

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mv public $out

      runHook postInstall
    '';
  };

  propagatedBuildInputs = [
    finalAttrs.gems.wrappedRuby
  ];

  buildInputs = [
    finalAttrs.gems
  ];

  postInstall = ''
    cp -R ${finalAttrs.frontend} $out/frontend
  '';

  meta = {
    description = "Web-based project management software";
    homepage = "https://github.com/opf/openproject";
    changelog = "https://github.com/opf/openproject/blob/${finalAttrs.src.tag}/CHANGELOG.md";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ niklaskorz ];
    mainProgram = "openproject";
    platforms = lib.platforms.all;
  };
})
