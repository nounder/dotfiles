{
  lib,
  stdenvNoCC,
  fetchurl,
  minisign,
}:

let
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  system = stdenvNoCC.hostPlatform.system;
  source = sources.systems.${system} or (throw "amp: unsupported system ${system}");
  baseUrl = "https://static.ampcode.com/cli/${sources.version}";

  binary = fetchurl {
    url = "${baseUrl}/amp-${source.target}";
    hash = source.hash;
  };

  signature = fetchurl {
    url = "${baseUrl}/amp-${source.target}.minisig";
    hash = source.signatureHash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "amp";
  version = sources.version;

  dontUnpack = true;
  nativeBuildInputs = [ minisign ];

  installPhase = ''
    runHook preInstall

    # The public key is committed separately from the release artifacts. A
    # matching hash alone protects reproducibility; this check also proves that
    # the artifact was signed by Amp's pinned release key.
    minisign -Vm ${binary} -x ${signature} -p ${./signing-key.pub}

    # Keep the verified binary out of $out/bin. Amp's self-updater writes a
    # fresh executable to $AMP_HOME/bin (default ~/.amp/bin) because it cannot
    # mutate the Nix store. A trampoline on PATH prefers that copy so
    # `amp update` actually changes the `amp` you run.
    install -Dm755 ${binary} "$out/libexec/amp"

    mkdir -p "$out/bin"
    cat > "$out/bin/amp" <<'WRAP'
#!/bin/sh
set -eu
amp_home="''${AMP_HOME:-$HOME/.amp}"
user_amp="$amp_home/bin/amp"
if [ -x "$user_amp" ]; then
  exec "$user_amp" "$@"
fi
exec "@libexec@" "$@"
WRAP
    substituteInPlace "$out/bin/amp" --replace-fail "@libexec@" "$out/libexec/amp"
    chmod +x "$out/bin/amp"

    runHook postInstall
  '';

  meta = {
    description = "Agentic coding tool by Sourcegraph";
    homepage = "https://ampcode.com/";
    mainProgram = "amp";
    license = lib.licenses.unfree;
    platforms = builtins.attrNames sources.systems;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
