{
  lib,
  runCommandCC,
  icu76,
}:
let
  icu = icu76.overrideAttrs (old: {
    configureFlags = old.configureFlags ++ [ "--disable-renaming" ];
  });
in
runCommandCC "libicucore" { } ''
  libs=$(find "${lib.getLib icu}/lib" -maxdepth 1 -name "*.dylib" ! -type l)
  flags=()
  for lib in $libs; do
    if [[ ! -L "$lib" ]]; then
      flags+=("-Wl,-reexport_library,$lib")
    fi
  done
  mkdir -p $out/lib
  clang -shared -o $out/lib/libicucore.A.dylib \
    "''${flags[@]}" \
    -Wl,-flat_namespace \
    -install_name $out/lib/libicucore.dylib
  ln -s $out/lib/{libicucore.A.dylib,libicucore.dylib}
''
