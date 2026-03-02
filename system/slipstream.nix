
{
  fetchFromGitHub,
  lib,
  rustPlatform,
  pkg-config,
  openssl,
  cmake,
  stdenv,
}:
let
  cmakeFix = [ "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" ];
  picotls = stdenv.mkDerivation {
    pname = "picotls";
    version = "2024-04-12"; # Use the commit suggested by slipstream-picoquic CMCMakeLists.txt for https://github.com/h2o/picotls.git
    src = fetchFromGitHub {
      owner = "h2o";
      repo = "picotls";
      rev = "5a4461d8a3948d9d26bf861e7d90cb80d8093515";
      hash = "sha256-Io0QZazs9BCXIYf3xZY7kgyRAiFexgzhcGFR+uh3jCI=";
      fetchSubmodules = true;
    };
    installPhase = ''
      mkdir -p $out/include $out/lib
      cp -r ../include/* $out/include/
      cp libpicotls*.a $out/lib/
    '';
    cmakeFlags = cmakeFix;
    nativeBuildInputs = [
      cmake
      pkg-config
    ];
    buildInputs = [ openssl ];
  };
  slipstream-picoquic = stdenv.mkDerivation {
    pname = "slipstream-picoquic";
    version = "2026-01-15";
    src = fetchFromGitHub {
      owner = "Mygod";
      repo = "slipstream-picoquic";
      rev = "4bd356c004a50ec46ee8a933ebd024da5d659f75";
      hash = "sha256-MMCA//7NxbdSC/wqMwCEQetUs+HxWdAGSNcZ9ysrvto=";
    };
    nativeBuildInputs = [
      cmake
      pkg-config
    ];
    buildInputs = [
      openssl
      picotls
    ];
    cmakeFlags = cmakeFix ++ [
      "-DPICOTLS_INCLUDE_DIR=${picotls}/include"
      "-DPICOTLS_LIBRARIES=${picotls}/lib/libpicotls-core.a" # Adjust filename if necessary
    ];
    CPATH = "${picotls}/include";
    LIBRARY_PATH = "${picotls}/lib";
    installPhase = ''
      mkdir -p $out/include $out/lib

      cp -r ../picoquic/*.h $out/include/
      find . -name "*.a" -exec cp {} $out/lib/ \;
      cp ${picotls}/lib/*.a $out/lib/
      cp -r ${picotls}/include/* $out/include/
    '';
  };
in
rustPlatform.buildRustPackage {
  pname = "slipstream-rust";
  version = "2026-02-22";

  src = fetchFromGitHub {
    owner = "Mygod";
    repo = "slipstream-rust";
    rev = "efd78e30fbcd00b042b169610072be9fb93ebafa";
    hash = "sha256-MA1Y0f3ki6Ysb2XeWYTTDVsIZlEkDHnEz00+VI1Qmeo=";
    fetchSubmodules = true;
  };

  cargoHash = "sha256-zvCOTaFRBNCdnoAk0CchBTz5kJOjlYC2yUBs40n0I2o=";
  cargoBuildFlags = [
    "-p slipstream-client"
    "-p slipstream-server"
  ];

  nativeBuildInputs = [
    pkg-config
    cmake
  ];
  buildInputs = [
    slipstream-picoquic
    picotls
    openssl
  ];

  PICOQUIC_AUTO_BUILD = "0";
  PICOQUIC_INCLUDE_DIR = "${slipstream-picoquic}/include";
  PICOTLS_INCLUDE_DIR = "${picotls}/include";
  PICOQUIC_LIB_DIR = "${slipstream-picoquic}/lib";

  doCheck = false;
  meta = with lib; {
    description = "High-performance multi-path covert channel over DNS in Rust with vibe coding";
    homepage = "https://github.com/Mygod/slipstream-rust";
    license = licenses.asl20;
    maintainers = with maintainers; [ nix-julia ];
  };
}

