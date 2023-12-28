{ lib, buildGoModule, fetchFromGitHub, olm, libsignal-ffi }:

buildGoModule {
  pname = "mautrix-signal";
  # mautrix-signal's latest released version v0.4.3 still uses the Python codebase
  # which is broken for new devices, see https://github.com/mautrix/signal/issues/388.
  # The new Go version fixes this by using the official libsignal as a library and
  # can be upgraded to directly from the Python version.
  version = "unstable-2023-12-27";

  src = fetchFromGitHub {
    owner = "mautrix";
    repo = "signal";
    rev = "fb18dcebcf611375ef4887041bc3b79008246178";
    hash = "sha256-WzBSwi0Q7azI2R0h/pTmP4eGp5SAdDROc+8T0w8u+ho=";
  };

  buildInputs = [ olm libsignal-ffi ];

  vendorHash = "sha256-05Kv0+pEcICPYKmt33SAQAMCsp471PGV2r9rE89xrCs=";

  # Required because the repository is a Go workspace.
  # Can be removed when https://github.com/mautrix/signal/pull/399 is merged.
  proxyVendor = true;

  doCheck = false;

  meta = with lib; {
    homepage = "https://github.com/mautrix/signal";
    description = "A Matrix-Signal puppeting bridge";
    license = licenses.agpl3Plus;
    maintainers = with maintainers; [ expipiplus1 niklaskorz ];
    mainProgram = "mautrix-signal";
  };
}
