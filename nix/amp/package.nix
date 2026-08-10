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

    install -Dm755 ${binary} "$out/bin/amp"

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
