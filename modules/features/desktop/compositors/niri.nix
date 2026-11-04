{
  baseVars,
  config,
  hostVars,
  lib,
  pkgs,
  selfPkgs,
  ...
}:
let
  monitors = hostVars.monitors;
  monitorNames = lib.attrNames monitors;
  transformedMonitors = lib.filterAttrs (_name: monitor: monitor ? transform) monitors;
  transformedMonitorNames = lib.attrNames transformedMonitors;

  formatMonitorMapping = names: render:
    lib.concatStringsSep "; " (map (name: "${name}:${render monitors.${name}}") names);
in
{
  config = lib.mkIf (hostVars.compositor == "niri") {
    programs.niri = {
      enable = true;
      package = selfPkgs.niri;
    };

    # The wrapper-provided user unit knows how to validate and hot-load its new
    # generated config. NixOS only daemon-reloads ordinary user services during
    # a switch, so explicitly invoke that reload for the real desktop user.
    system.userActivationScripts.reloadNiri = {
      text = ''
        if [ "$(${lib.getExe' pkgs.coreutils "id"} -un)" = ${lib.escapeShellArg baseVars.username} ] \
          && ${lib.getExe' pkgs.systemd "systemctl"} --user is-active --quiet niri.service
        then
          ${lib.getExe' pkgs.systemd "systemctl"} --user reload niri.service
        fi
      '';
    };

    services.displayManager.noctalia-greeter = {
      enable = true;
      passwordlessSyncUsers = [ baseVars.username ];
      settings = {
        session.default = "niri";

        # Keep the greeter's logical geometry identical to the compositor's.
        # This also avoids relying on Noctalia Sync to infer fractional scale
        # for a rotated output, which currently leaves the greeter at 1x.
        output = lib.mkIf (monitorNames != [ ]) (
          {
            layout = formatMonitorMapping monitorNames (
              monitor: "${toString monitor.position.x},${toString monitor.position.y}"
            );
            scales = formatMonitorMapping monitorNames (monitor: toString monitor.scale);
          }
          // lib.optionalAttrs (transformedMonitorNames != [ ]) {
            transforms = formatMonitorMapping transformedMonitorNames (monitor: monitor.transform);
          }
        );
      };
    };

    # The Nouveau DRM node appears shortly after graphical.target on Fermi.
    # Tag it for systemd and order greetd behind it so the greeter compositor
    # does not start once with zero GPUs, exit, and visibly restart.
    services.udev.extraRules = lib.mkIf (hostVars.hostName == "fermi") ''
      SUBSYSTEM=="drm", KERNEL=="card0", TAG+="systemd"
    '';

    systemd.services.greetd = lib.mkIf (hostVars.hostName == "fermi") {
      wants = [ "dev-dri-card0.device" ];
      after = [ "dev-dri-card0.device" ];
    };

    # The shell writes its synced palette, wallpaper, and output settings here.
    preferences.impermanence.persist.systemDirectories = lib.mkAfter [
      {
        directory = "/var/lib/noctalia-greeter";
        user = "greeter";
        group = "greeter";
        mode = "0750";
      }
    ];

    # Impermanence creates a new backing directory on the first switch. Seed
    # it with an already-synced live state before systemd activates the bind
    # mount, then leave every later activation untouched.
    system.activationScripts.seedNoctaliaGreeterPersistence = lib.mkIf config.preferences.impermanence.enable {
      deps = [ "createPersistentStorageDirs" ];
      text = ''
        greeter_live=/var/lib/noctalia-greeter
        greeter_persistent=/persist/var/lib/noctalia-greeter

        if [ -f "$greeter_live/sync.toml" ] && [ ! -e "$greeter_persistent/sync.toml" ]; then
          ${lib.getExe' pkgs.coreutils "cp"} --archive "$greeter_live/." "$greeter_persistent/"
        fi
      '';
    };
  };
}
