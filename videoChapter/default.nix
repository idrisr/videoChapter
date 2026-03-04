{ mkDerivation
, aeson
, base
, http-client
, http-client-tls
, http-types
, bytestring
, containers
, fmt
, lib
, optparse-applicative
, process
, text
, time
}:
mkDerivation {
  pname = "videoChapter";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    aeson
    base
    bytestring
    containers
    fmt
    http-client
    http-client-tls
    http-types
    optparse-applicative
    process
    text
    time
  ];
  description = "Extract and display video chapter information";
  license = lib.licenses.mit;
  mainProgram = "videoChapter";
}
