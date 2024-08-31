{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs-slim,
  yarn-berry_3,
  pkg-config,
  python311,
  cctools,
  xcbuild,
  prisma-engines,
  vips,
  inter,
  makeWrapper,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "calcom";
  version = "5.9.12";

  src = fetchFromGitHub {
    owner = "calcom";
    repo = "cal.com";
    rev = "v${finalAttrs.version}";
    hash = "sha256-fQJfFY+f/E1ToGYyvgItrIntciYMcr6Wx0MXHX2A9CU=";
  };

  missingHashes = ./missing-hashes.json;
  offlineCache = yarn-berry_3.fetchYarnBerryDeps {
    inherit (finalAttrs) src missingHashes;
    hash = "sha256-eemUSow03Ep0Pn3W3AhL3WI1XRykjyoC698r/vQjIEY=";
  };

  nativeBuildInputs = [
    nodejs-slim
    yarn-berry_3
    yarn-berry_3.yarnBerryConfigHook
    pkg-config
    python311
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    xcbuild
    cctools.libtool
  ];
  buildInputs = [ vips ];

  env = {
    npm_config_nodedir = nodejs-slim;
    YARN_ENABLE_TELEMETRY = "0";
    NODE_ENV = "production";
    BUILD_STANDALONE = "true";

    PRISMA_SCHEMA_ENGINE_BINARY = "${prisma-engines}/bin/schema-engine";
    PRISMA_QUERY_ENGINE_BINARY = "${prisma-engines}/bin/query-engine";
    PRISMA_QUERY_ENGINE_LIBRARY = "${prisma-engines}/lib/libquery_engine.node";
    PRISMA_GENERATE_SKIP_AUTOINSTALL = "1";
    PRISMA_SKIP_POSTINSTALL_GENERATE = "1";

    NEXT_PUBLIC_WEBAPP_URL = "http://NEXT_PUBLIC_WEBAPP_URL_PLACEHOLDER";
    NEXT_PUBLIC_API_V2_URL = "http://localhost:5555/api/v2";

    #   - NEXTAUTH
    # @see: https://github.com/calendso/calendso/issues/263
    # @see: https://next-auth.js.org/configuration/options#nextauth_url
    # Required for Vercel hosting - set NEXTAUTH_URL to equal your NEXT_PUBLIC_WEBAPP_URL
    NEXTAUTH_URL = "http://localhost:3000";
    # @see: https://next-auth.js.org/configuration/options#nextauth_secret
    # You can use: `openssl rand -base64 32` to generate one
    NEXTAUTH_SECRET = "secret";
    # Used for cross-domain cookie authentication
    NEXTAUTH_COOKIE_DOMAIN = "";

    # Set this to '1' if you don't want Cal to collect anonymous usage
    CALCOM_TELEMETRY_DISABLED = "1";

    # Application Key for symmetric encryption and decryption
    # must be 32 bytes for AES256 encryption algorithm
    # You can use: `openssl rand -base64 32` to generate one
    CALENDSO_ENCRYPTION_KEY = "secret";
  };

  buildPhase = ''
    runHook preBuild

    # Ensure we only include the parts covered by the AGPL,
    # see https://github.com/calcom/cal.com/blob/main/LICENSE
    # Must happen after `yarn install` so the lockfile matches
    # TODO: this involves a lot of parts to manually remove imports to these...
    # not sure how feasible this is
    #rm -rf packages/features/ee
    #rm -rf apps/api/v2/src/ee

    # Replace the googleapis.com Inter font with a local copy from nixpkgs
    cp "${inter}/share/fonts/truetype/InterVariable.ttf" apps/web/fonts/Inter.ttf

    yarn --cwd packages/embeds/embed-core workspace @calcom/embed-core run build
    yarn --cwd apps/web workspace @calcom/web run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,share}
    target=$out/share/calcom

    mv apps/web/.next/standalone $target
    mv apps/web/.next/static $target/apps/web/.next/static
    rm -rf $target/apps/web/public
    mv apps/web/public $target/apps/web/public

    makeWrapper "${lib.getExe nodejs-slim}" "$out/bin/calcom" \
      --add-flags "$target/apps/web/server.js" \
      --set PRISMA_SCHEMA_ENGINE_BINARY ${prisma-engines}/bin/schema-engine \
      --set PRISMA_QUERY_ENGINE_BINARY ${prisma-engines}/bin/query-engine \
      --set PRISMA_QUERY_ENGINE_LIBRARY ${lib.getLib prisma-engines}/lib/libquery_engine.node

    runHook postInstall
  '';

  meta = {
    description = "A scheduling tool that lets you control your own data, workflow, and appearance";
    homepage = "https://github.com/calcom/cal.com";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ niklaskorz ];
    mainProgram = "calcom";
    platforms = lib.platforms.all;
  };
})
