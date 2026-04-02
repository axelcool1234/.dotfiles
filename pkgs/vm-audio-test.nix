{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "vm-audio-test";

  runtimeInputs = [
    pkgs.alsa-utils
    pkgs.pipewire
  ];

  text = ''
    set -eu

    echo "== ALSA devices =="
    aplay -l || true
    echo

    echo "== PipeWire nodes =="
    pw-cli ls Node | sed -n '1,120p' || true
    echo

    echo "== Test tone =="
    echo "Playing a short stereo sine wave with speaker-test..."
    echo "If you hear alternating left/right output, guest audio is working."
    speaker-test -t sine -f 440 -c 2 -l 1
  '';
}
