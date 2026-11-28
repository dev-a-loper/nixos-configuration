# sing-box-extended — nixpkgs' sing-box, rebuilt from the shtorm-7 fork with
# the extra protocol tags chproxy's templates rely on. Deliberately an
# override of the nixpkgs derivation: build logic, patches and the base tags
# come from nixpkgs, only the source, version and the extended gates differ.
# The hashes are tied to nixos-26.05's sing-box, so a nixpkgs bump that
# changes that derivation may need them refreshed.
{
  pkgs,
}:
pkgs.sing-box.overrideAttrs (
  finalAttrs: prevAttrs: {
    pname = "sing-box-extended";
    version = "1.14.3-extended-2.7.3";

    src = pkgs.fetchFromGitHub {
      owner = "shtorm-7";
      repo = "sing-box-extended";
      tag = "v${finalAttrs.version}";
      hash = "sha256-1xopWHom+RZLhjhScUpA3UFvS4DjJVaXc2zJcTnfcTQ=";
    };

    vendorHash = "sha256-r51H+rVlK6wR+bdtQSPUNJAOCr1/Oy3wUeYPOyw2bEU=";

    # keep everything nixpkgs builds sing-box with, add the extended gates
    tags = prevAttrs.tags ++ [
      "with_masque"
      "with_mtproxy"
      "with_trusttunnel"
      "with_call"
      "with_sudoku"
    ];

    meta = prevAttrs.meta // {
      description = "Universal proxy platform (extended fork)";
      homepage = "https://github.com/shtorm-7/sing-box-extended";
      maintainers = [ ];
    };
  }
)
