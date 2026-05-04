{
  lib,
  stdenv,
  vlang,
  coreutils,
  fetchFromGitHub,
}:

stdenv.mkDerivation rec {
  pname = "vls";
  version = "0.1";

  src = fetchFromGitHub {
    owner = "vlang"; # GitHub username or org
    repo = "vls"; # Repo name
    rev = "0f4ee5c5c2e32eaa3d95ca33391c6836eb19030f"; # Tag, branch, or commit hash
    sha256 = "sha256-HcncwMFkA2R60wmo6bdkHc2RiEQsxfeGtk6DXpihpPs="; # Fill this after first run
  };

  buildInputs = [
    vlang
  ];

  nativeBuildInputs = [
    coreutils
  ];

  preBuild = ''
    export HOME=$(mktemp -d)
  '';

  buildPhase = ''
    export HOME=$TMPDIR
    export XDG_CACHE_HOME=$TMPDIR
    v -prod -cflags "-O3" . -o vls
    strip -s vls
  '';

  installPhase = ''
    mkdir -p $out/bin
    mv vls $out/bin
  '';

  meta = {
    description = "Low-level hardware control utility for AMD GPUs on Linux";
    homepage = "https://github.com/ehsan2003/vls";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "vls";
  };
}
