export def main [...args: string] {
  let input = $in
  if $input == null {
    tmux new-session -d -s headless-helix $"hx \"($args.0)\""
    sleep 0.05sec
    tmux send-keys -t headless-helix ...($args | skip 1) C-o ":wq" enter
    open $args.0
  } else {
    rm -f "/tmp/headless-helix"
    tmux new-session -d -s headless-helix $"echo \"($input)\" | hx"
    sleep 0.05sec
    tmux send-keys -t headless-helix ...($args) C-o ":wq /tmp/headless-helix" enter
    sleep 0.05sec
    open "/tmp/headless-helix"
  }
}