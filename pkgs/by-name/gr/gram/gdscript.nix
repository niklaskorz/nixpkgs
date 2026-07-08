{
  rustPlatform,
  fetchFromGitHub,
  tree-sitter,
  tree-sitter-grammars,
  lld,
  wasm-component-ld,
}:

let
  tree-sitter-gdscript = tree-sitter.buildGrammar {
    language = "gdscript";
    version = "0b9f60ebaa1c31f5153dd3a3b283ca0725734378";
    src = fetchFromGitHub {
      owner = "PrestonKnopp";
      repo = "tree-sitter-gdscript";
      rev = "0b9f60ebaa1c31f5153dd3a3b283ca0725734378";
      hash = "sha256-AqKF6nJcWlt9+xrKKImY71UF5KGdF1eVf0pa6WCUVac=";
    };
  };
in

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "gdscript-extension";
  version = "0.9.0";

  src = fetchFromGitHub {
    owner = "GDQuest";
    repo = "zed-gdscript";
    tag = finalAttrs.version;
    hash = "sha256-AK3vcDoIWxRky7sXbXTtjy5whNDA1+rim6O8lyiMxlg=";
  };

  postPatch = ''
    cp ${./gdscript.lock} Cargo.lock
  '';

  cargoLock.lockFile = ./gdscript.lock;

  #cargoBuildFlags = [ "--target=wasm32-wasip2" ];

  nativeBuildInputs = [
    lld # contains wasm-ld, required by wasm-component-ld
    wasm-component-ld
  ];
  env.RUSTFLAGS = "-C linker=wasm-component-ld";

  installPhase = ''
    mkdir -p $out
    mv target/wasm32-wasip2/release/zed_gdscript.wasm $out/extension.wasm
    mv extension.toml $out/
    mv languages $out/
    mv debug_adapter_schemas $out/

    mkdir -p $out/grammars
    ln -s ${tree-sitter-gdscript}/parser.wasm $out/grammars/gdscript.wasm
    ln -s ${tree-sitter-grammars.tree-sitter-godot-resource}/parser.wasm $out/grammars/godot_resource.wasm
  '';
})
