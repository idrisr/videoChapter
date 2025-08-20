{ mkDerivation, aeson, base, bytestring, containers, fmt, lib
, optparse-applicative, text, time
}:
mkDerivation {
  pname = "videoChapter";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    aeson base bytestring containers fmt optparse-applicative text time
  ];
  description = "Extract and display video chapter information";
  license = lib.licenses.mit;
  mainProgram = "videoChapter";
}
