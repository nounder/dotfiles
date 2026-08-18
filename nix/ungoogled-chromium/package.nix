{
  lib,
  stdenv,
  fetchurl,
  undmg,
}:

let
  version = "150.0.7871.46-1.1";

  sources = {
    aarch64-darwin = {
      arch = "arm64";
      hash = "sha256-/nVIrUNuN7unIx+GRVHYj3f2aX/OHHtpQvq4Ep6KB5o=";
    };
    x86_64-darwin = {
      arch = "x86_64";
      hash = "sha256-nVBwlca+4d/rTQNhTT0BYeXZhxs+omhIKfZjykgm1dE=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "ungoogled-chromium-macos: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "ungoogled-chromium";
  inherit version;

  src = fetchurl {
    url = "https://github.com/ungoogled-software/ungoogled-chromium-macos/releases/download/${version}/ungoogled-chromium_${version}_${source.arch}-macos.dmg";
    inherit (source) hash;
  };

  nativeBuildInputs = [ undmg ];

  unpackPhase = ''
    runHook preUnpack
    undmg "$src"
    runHook postUnpack
  '';

  buildPhase = ''
    runHook preBuild
    $CC -Os -Wall -Wextra -Werror ${./launcher.c} -o ungoogled-chromium-launcher
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications" "$out/bin" "$out/libexec"
    cp -R Chromium.app "$out/Applications/Chromium.app"
    install -m755 ungoogled-chromium-launcher "$out/libexec/ungoogled-chromium-launcher"
    cat > "$out/bin/ungoogled-chromium" <<EOF
    #!/bin/sh
    exec "$out/Applications/Chromium.app/Contents/MacOS/Chromium" "\$@"
    EOF
    chmod +x "$out/bin/ungoogled-chromium"
    ln -s ungoogled-chromium "$out/bin/chromium"
    ln -s ungoogled-chromium "$out/bin/chromium-browser"

    runHook postInstall
  '';

  # Preserve the upstream application bundle and its code signature.
  dontFixup = true;

  meta = {
    description = "Chromium without integration with Google web services";
    homepage = "https://github.com/ungoogled-software/ungoogled-chromium";
    changelog = "https://github.com/ungoogled-software/ungoogled-chromium-macos/releases/tag/${version}";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "ungoogled-chromium";
  };
}
