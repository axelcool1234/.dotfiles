{ writeShellApplication, nh }:

writeShellApplication {
  name = "ns";
  runtimeInputs = [ nh ];

  text = ''
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
