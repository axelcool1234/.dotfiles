{ pkgs, ... }:
{
  # Use PipeWire as the main audio server.
  #
  # `services.pulseaudio.enable = false` disables the old PulseAudio daemon.
  # We still keep PipeWire's PulseAudio compatibility layer enabled so programs
  # that speak the Pulse protocol continue to work.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
    jack.enable = true;
  };

  environment.systemPackages = [
    pkgs.pwvucontrol
    pkgs.alsa-utils
  ];
}
