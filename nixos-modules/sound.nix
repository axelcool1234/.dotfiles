{ pkgs, lib, config, ... }:

{
  options = {
    sound-control.enable =
      lib.mkEnableOption "enables pamixer and pavucontrol";
  };
  config = {
    # Enable sound with pipewire.
    sound.enable = true;
    hardware.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
      jack.enable = true;

      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
      #media-session.enable = true;
    };
    environment.systemPackages = with pkgs; lib.mkIf config.sound-control.enable [
      pamixer
      pavucontrol
    ];
  };
}
