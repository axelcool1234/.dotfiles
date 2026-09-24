{ selfPkgs, ... }:
{
  # Pear Desktop loads CSS files listed in `options.themes`. Its wrapper points
  # at this writable output while Noctalia regenerates the colors when the
  # active scheme changes.
  userTemplates.templates.pear-desktop = {
    input_path = ./pear-desktop.css;
    output_path = "~/.config/YouTube Music/noctalia.css";
    post_hook = ''
      ${selfPkgs.pear-desktop.passthru.reloadPearDesktopTheme} \
        "$HOME/.config/YouTube Music/noctalia.css" || true
    '';
  };
}
