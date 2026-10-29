{ pkgs, ... }:
let
  # brand-new single-author app: pinned to a reviewed commit; before bumping, read
  # the diff for new hosts, spawned programs, or writes outside ~/.local/share/tuinews
  tuinews = pkgs.rustPlatform.buildRustPackage {
    pname = "tuinews";
    version = "0.2.1";
    src = pkgs.fetchFromGitHub {
      owner = "erictran308";
      repo = "tuinews";
      rev = "a36fd12bac66791c0fcff2f30c2c9a56ecb7f2ba"; # v0.2.1, reviewed 2026-10-30
      hash = "sha256-YxvQadCSUiu2MzSRBT6Uf+AUyWAfbnBDdik1sU+K9TA=";
    };
    cargoHash = "sha256-jslXmxdB3gUL1B9FGmhJ9qhODfOiphCMkNLwfu86zms=";
    # tests build an http client (needs CA certs) and refuse a data folder outside $HOME
    nativeCheckInputs = [ pkgs.cacert ];
    preCheck = "export HOME=$(mktemp -d)";
    # the sandbox's / is writable by the build user, which this check rightly rejects
    checkFlags = [ "--skip=config::tests::a_data_folder_others_could_swap_out_is_refused" ];
  };
in
{
  home.packages = [ tuinews ];
}
