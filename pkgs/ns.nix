{ writeShellApplication, nh }:

writeShellApplication {
  name = "ns";
  runtimeInputs = [ nh ];

  text = ''
    # ns: nix switch
    #
    # Minimal system-and-home switch script for this dotfiles repo.
    #
    # Flow:
    # 1. Run `nh os switch .` from the repo root.
    # 2. If that succeeds, run `nh home switch .`.

    repo_root="$HOME/.dotfiles"

    if [ ! -d "$repo_root" ]; then
      echo "dotfiles repo not found at $repo_root" >&2
      exit 1
    fi

    cd "$repo_root"

    nh os switch .
    nh home switch .
  '';
}
