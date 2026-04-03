{ config, lib, pkgs, ... }:
let
  cfg = config.preferences.grub;

  themeCount = builtins.length cfg.themes;
  themeIndices = lib.genList (index: index) themeCount;
  initialThemeIndex = if themeCount == 0 then 0 else lib.mod cfg.initialThemeIndex themeCount;

  themeFiles = theme:
    map toString (lib.filesystem.listFilesRecursive theme);

  relativeThemePath = theme: path:
    lib.removePrefix "${toString theme}/" path;

  themeFonts = theme:
    map (relativeThemePath theme) (
      builtins.filter (path: lib.hasSuffix ".pf2" (lib.toLower path)) (themeFiles theme)
    );

  themeNeedsExtension = extension: theme:
    builtins.any (path: lib.hasSuffix extension (lib.toLower path)) (themeFiles theme);

  themesNeedPng = builtins.any (themeNeedsExtension ".png") cfg.themes;
  themesNeedJpeg = builtins.any (
    theme: (themeNeedsExtension ".jpg" theme) || (themeNeedsExtension ".jpeg" theme)
  ) cfg.themes;
  themesNeedFonts = builtins.any (theme: themeFonts theme != [ ]) cfg.themes;

  themePrepareCommands = lib.concatMapStringsSep "\n" (
    index:
    let
      theme = builtins.elemAt cfg.themes index;
    in
    ''
      ${pkgs.coreutils}/bin/mkdir -p @bootPath@/grub/themes/${toString index}
      ${pkgs.coreutils}/bin/cp -rT ${lib.escapeShellArg (toString theme)} @bootPath@/grub/themes/${toString index}
    ''
  ) themeIndices;

  renderThemeBranch = index:
    let
      theme = builtins.elemAt cfg.themes index;
      clauseKeyword = if index == 0 then "if" else "elif";
      fontCommands = lib.concatMapStringsSep "\n" (
        font:
        ''
          loadfont "''${prefix}/themes/${toString index}/${font}"
        ''
      ) (themeFonts theme);
    in
    ''
      ${clauseKeyword} [ "''${theme_slot}" = "${toString index}" ]; then
        set theme="''${prefix}/themes/${toString index}/theme.txt"
        export theme
${fontCommands}
    '';

  themeSelectionConfig = ''
    # Select the GRUB theme for this boot from the persisted theme slot.
    if [ -z "''${theme_slot}" ]; then
      set theme_slot=${toString initialThemeIndex}
    fi

${lib.optionalString themesNeedPng ''
    insmod png
''}${lib.optionalString themesNeedJpeg ''
    insmod jpeg
''}${lib.optionalString themesNeedFonts ''
    insmod font
''}${lib.concatMapStringsSep "\n" renderThemeBranch themeIndices}
    else
      set theme_slot=${toString initialThemeIndex}
      set theme="''${prefix}/themes/${toString initialThemeIndex}/theme.txt"
      export theme
${lib.concatMapStringsSep "\n" (
      font:
      ''
        loadfont "''${prefix}/themes/${toString initialThemeIndex}/${font}"
      ''
    ) (themeFonts (builtins.elemAt cfg.themes initialThemeIndex))}
    fi
  '';

  grubThemeAdvanceScript = pkgs.writeShellScript "advance-grub-theme-slot" ''
    set -eu

    esp_mount_point=${lib.escapeShellArg cfg.efiSysMountPoint}
    if ! ${pkgs.util-linux}/bin/findmnt -M "$esp_mount_point" >/dev/null 2>&1; then
      echo "EFI mount point $esp_mount_point is not mounted; refusing to update grubenv" >&2
      exit 1
    fi

    grubenv_path=${lib.escapeShellArg "${cfg.efiSysMountPoint}/grub/grubenv"}
    current_slot=$(
      ${pkgs.grub2}/bin/grub-editenv "$grubenv_path" list 2>/dev/null \
        | ${pkgs.gnused}/bin/sed -n 's/^theme_slot=//p' \
        | ${pkgs.coreutils}/bin/head -n 1
    )

    if ! [ -e "$grubenv_path" ]; then
      ${pkgs.grub2}/bin/grub-editenv "$grubenv_path" create
      current_slot=${toString initialThemeIndex}
    fi

    if ! ${pkgs.coreutils}/bin/printf '%s\n' "$current_slot" \
      | ${pkgs.gnugrep}/bin/grep -Eq '^[0-9]+$'
    then
      current_slot=${toString initialThemeIndex}
    fi

    next_slot=$(( (current_slot + 1) % ${toString themeCount} ))
    ${pkgs.grub2}/bin/grub-editenv "$grubenv_path" set theme_slot="$next_slot"
  '';
in
{
  options.preferences.grub = {
    # Repo-local source of truth for the EFI System Partition mount point.
    #
    # NixOS already exposes `boot.loader.efi.efiSysMountPoint`, but keeping a
    # custom option here makes it easy for other repo modules to reference the
    # same value without duplicating a literal like `/boot`.
    efiSysMountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/boot";
      description = "Mount point for the EFI System Partition used by the GRUB feature.";
    };

    themes = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      example = lib.literalExpression ''
        [
          "''${pkgs.some-grub-theme}/grub/themes/theme-a"
          "''${pkgs.some-other-grub-theme}/grub/themes/theme-b"
        ]
      '';
      description = ''
        GRUB themes to copy into `/boot/grub/themes`.

        When this list is non-empty, GRUB reads a `theme_slot` value from
        `grubenv` and uses that slot to pick the theme for the current boot.
        A boot-time service then advances the slot so the next reboot uses the
        following theme.
      '';
    };

    initialThemeIndex = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 0;
      description = ''
        Theme slot used when `grubenv` does not yet contain a valid
        `theme_slot` value.
      '';
    };
  };

  config = lib.mkMerge [
    {
      boot.loader = {
        efi = {
          # Mount point for the EFI System Partition (ESP).
          # This is where GRUB's EFI files are installed.
          efiSysMountPoint = cfg.efiSysMountPoint;

          # Allow NixOS to update EFI boot entries in firmware.
          # Needed on most normal UEFI installs.
          canTouchEfiVariables = true;
        };

        grub = {
          # Use GRUB as the bootloader.
          enable = true;

          # Build/install the EFI GRUB target instead of a BIOS/MBR setup.
          efiSupport = true;

          # Detect other operating systems and add them to the GRUB menu.
          # Useful for dual-boot setups.
          useOSProber = true;

          # No block device install target for pure EFI setups.
          # GRUB is installed into the EFI partition instead.
          device = "nodev";
        };
      };
    }

    (lib.mkIf (themeCount > 0) {
      boot.loader.grub = {
        # The built-in single-theme option copies one directory to `/boot/theme`.
        # Theme rotation manages its own `/boot/grub/themes/<slot>` layout.
        theme = lib.mkForce null;

        extraPrepareConfig = lib.mkAfter ''
          ${pkgs.coreutils}/bin/rm -rf @bootPath@/grub/themes
          ${pkgs.coreutils}/bin/mkdir -p @bootPath@/grub/themes
${themePrepareCommands}
        '';

        extraConfig = lib.mkAfter themeSelectionConfig;
      };

      systemd.services.grub-theme-slot = {
        description = "Advance the GRUB theme slot for the next boot";
        after = [ "local-fs.target" ];
        unitConfig.RequiresMountsFor = cfg.efiSysMountPoint;
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = grubThemeAdvanceScript;
        };
      };
    })
  ];
}
