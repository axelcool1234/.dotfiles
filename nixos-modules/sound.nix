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

      # This adds a noise suppression plugin to pipewire so I can actually talk on Discord. 
      extraLv2Packages = [ pkgs.rnnoise-plugin ];
      configPackages = [
        (pkgs.writeTextDir "share/pipewire/pipewire.conf.d/20-rnnoise.conf" ''
          context.modules = [
          {   name = libpipewire-module-filter-chain
              args = {
                  node.description = "Noise Canceling source"
                  media.name = "Noise Canceling source"
                  filter.graph = {
                      nodes = [
                          {
                              type = lv2
                              name = rnnoise
                              plugin = "https://github.com/werman/noise-suppression-for-voice#stereo"
                              label = noise_suppressor_stereo
                              control = {
                              }
                          }
                      ]
                  }
                  capture.props = {
                      node.name =  "capture.rnnoise_source"
                      node.passive = true
                  }
                  playback.props = {
                      node.name =  "rnnoise_source"
                      media.class = Audio/Source
                  }
              }
          }
          ]
        '')
      ];
    };
    environment.systemPackages = with pkgs; lib.mkIf config.sound-control.enable [
      pamixer
      pavucontrol
    ];
  };
}
