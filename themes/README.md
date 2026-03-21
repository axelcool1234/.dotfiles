# Themes

`themes/` is the canonical theme library for this dotfiles repo.

The important idea is that a theme is just data. The family files in this directory do
not directly configure programs. Instead, they describe:

- what theme is selected
- how each app receives that theme
- any small bits of shared derived data that are still needed locally

The Home Manager and NixOS modules outside this directory then realize that plan into
actual config files, package choices, or copied upstream assets.

## Core Idea

A **theme bundle** is the concrete result of selecting a theme **family** and then
describing how individual **apps** receive that theme.

In this repo:

- a **family** is something like Catppuccin
- the family chooses a **source** such as `variant = "mocha"` and `accent = "teal"`
- the family also defines an `apps` map describing how each app gets themed

So a theme bundle is best thought of as:

```text
family selection
  +
per-app delivery records
  +
small shared derived data
  =
theme bundle
```

That is why the bundle has both:

- `source`
  Which member of the family was selected.

- `apps`
  How each app receives that family's theme.

The `apps` field is not a side detail. It is one of the main parts of the bundle.

## What Lives Here

- [`default.nix`](/home/axelcool1234/.dotfiles/themes/default.nix)
  Public entrypoint. Imports helpers and all theme families.

- [`lib.nix`](/home/axelcool1234/.dotfiles/themes/lib.nix)
  Shared constructors and helper functions used by families and realizers.

- [`families/`](/home/axelcool1234/.dotfiles/themes/families)
  Theme family definitions. Right now Catppuccin is the only implemented family.

  A family file usually exports both:

  - constructor functions such as `mk`, `mkSource`, `mkApps`, and `mkData`
  - a default precomputed `source`, `apps`, and `data` for the family's default selection

- [`wrappers/`](/home/axelcool1234/.dotfiles/themes/wrappers)
  Small static wrapper files for apps that want an existing config to `@import` or
  `source` an upstream asset rather than replacing the whole config.

## Naming Conventions

The current naming in the codebase is:

- `themes`
  The library of family definitions and helper functions.

- `theme`
  The selected theme bundle passed through flake `specialArgs`.

- `apps.<name>.provider`
  The per-app delivery record.

`provider` is not a perfect name. Conceptually it really means "how this app receives
its theme".

## Public Shape

Import the theme library from the flake and choose a family bundle:

```nix
let
  themes = import ./themes { inherit lib; };
  theme = themes.families.catppuccin.mk {
    source = {
      variant = "mocha";
      accent = "teal";
    };
  };
in
{
  # Pass `theme` through flake specialArgs.
}
```

The selected bundle has this shape:

```nix
{
  meta = { ... };
  source = { ... };
  apps = { ... };
  data = { ... };
}
```

- `meta`
  Human-oriented metadata like family title and title-cased variant names.

- `source`
  The selected family member: family id, variant, accent, and mode.

- `apps`
  Per-app delivery records describing how each app receives the selected family theme.

- `data`
  Shared derived values that are still useful outside the app records, such as the
  wallpaper path. This should stay small. If a value only matters to one app, it should
  usually live in that app's own record instead.

As a rule of thumb:

- if a value is only used by one app, keep it on that app's `provider.options`
- if multiple realizers need it, keep it in `data`
- if upstream already ships the thing you need, prefer an upstream asset over derived data

## Family Exports

A family object such as `themes.families.catppuccin` is not itself the final theme
bundle. It is a small API for building one.

The most important export is:

- `mk`
  Builds the final theme bundle.

Families may also expose lower-level helpers:

- `mkSource`
  Builds the family-selection record.

- `mkApps`
  Builds the per-app delivery records for a given selection.

- `mkData`
  Builds any remaining shared derived data for a given selection.

And many family files also expose precomputed defaults:

- `source`
- `apps`
- `data`

Those are just the default results of calling the lower-level constructors with the
family's default selection.

So if you see code like:

```nix
source = mkSource { };
apps = mkApps source;
data = mkData source defaultWallpaper;
```

that means:

- `mkSource { }` builds the default family selection
- `mkApps source` builds the default app records for that selection
- `mkData source ...` builds the default shared data for that selection

The final bundle is still the thing returned by `mk`.

## App Records

The `apps` attribute is where the family says, app by app, what the delivery strategy is.

Examples:

- `theme.apps.starship`
  says how Starship receives Catppuccin.

- `theme.apps.kvantum`
  says how Kvantum receives Catppuccin.

- `theme.apps.code`
  says how the local Code config receives Catppuccin.

Each entry under `apps` has this general shape:

```nix
{
  enable = true;
  provider = { ... };
  notes = [ ... ];
}
```

### Provider Kinds

These names are the current contract between the theme families and the realizing
modules.

- family files construct app entries with a specific provider kind
- helper functions such as [`getAppProvider`](/home/axelcool1234/.dotfiles/themes/lib.nix)
  return those provider records to consumers
- realizing modules branch on `provider.type` to decide how to materialize the theme

So these are more than just documentation. They are implementation-level conventions the
current modules rely on. That said, some of those checks are still somewhat brittle and
may be generalized later if more theme families are added.

- `module`
  A NixOS or Home Manager module consumes structured options from the theme.
  This is typically used for things like qt, GTK, NixOS Module console colors.

- `package`
  The app wants a package or plugin from a package set such as `pkgs.vimPlugins`.

- `asset`
  Copy an upstream asset file or directory into place.

- `asset+import`
  Copy an upstream asset, but keep a small repo-local wrapper config that imports it.

- `template`
  The consuming module renders some local text directly from provider options.

- `stylix`
  Reserved for apps themed directly by Stylix.

- `custom`
  Reserved for fully custom local-file-backed app handling. 

## Source Kinds

Theme bundles also carry a top-level `source.type`. These names are also defined in
[`themes/lib.nix`](/home/axelcool1234/.dotfiles/themes/lib.nix).

- `family`
  A source selected from a known family such as Catppuccin.

- `stylix`
  Reserved for a future source driven directly by Stylix.

### Typical Examples

- `asset`
  Discord CSS, Hyprland theme fragments, Yazi themes, Zathura themes.

- `asset+import`
  Waybar, Rofi, and Wlogout, where this repo keeps a tiny wrapper config but imports an
  upstream asset or locally generated palette fragment.

- `module`
  GTK, Kvantum, Qt, cursors, console colors, or WezTerm builtin scheme selection.

- `package`
  Neovim plugins and Spicetify themes.

- `template`
  Small generated local config, such as the `code` theme section.

## How Realization Works

This directory does not write files by itself.

The actual realization points are:

- [`home-modules/theme/default.nix`](/home/axelcool1234/.dotfiles/home-modules/theme/default.nix)
  Realizes shared theme assets such as wallpapers, copied config fragments, and a few
  tiny generated files.

- [`home-modules/hyprland-desktop/default.nix`](/home/axelcool1234/.dotfiles/home-modules/hyprland-desktop/default.nix)
  Uses theme app records for desktop-adjacent config like Dunst, Waybar markup colors,
  Rofi, Wlogout, GTK, and Kvantum.

- [`nixos-modules/hyprland/theme.nix`](/home/axelcool1234/.dotfiles/nixos-modules/hyprland/theme.nix)
  Uses theme app records for system-side desktop settings like Qt, cursors, and console
  colors.

- App-specific modules such as [`home-modules/terminal/starship/default.nix`](/home/axelcool1234/.dotfiles/home-modules/terminal/starship/default.nix) or [`home-modules/programs/code/default.nix`](/home/axelcool1234/.dotfiles/home-modules/programs/code/default.nix)
  Pull their own app record and realize it locally.

In other words, the flow is:

```text
themes/families/catppuccin.nix
  -> returns a theme bundle
  -> flake passes that bundle as `theme`
  -> modules inspect `theme.apps.<app>.provider`
  -> modules copy assets, choose packages, or render tiny fragments
```

The `themes/` directory is deliberately dumb about side effects. It describes; the app
modules (such as those in `home-modules`) realize.

## Current Realizers

Useful places to look when changing behavior:

- [`home-modules/theme/default.nix`](/home/axelcool1234/.dotfiles/home-modules/theme/default.nix)
  Shared asset realization. This is the closest thing to a general theme dispatcher.

- [`home-modules/hyprland-desktop/default.nix`](/home/axelcool1234/.dotfiles/home-modules/hyprland-desktop/default.nix)
  Desktop integration glue. It consumes provider options for Dunst, Waybar colors,
  Rofi, Wlogout, GTK, Kvantum, and cursor-related settings.

- [`nixos-modules/hyprland/theme.nix`](/home/axelcool1234/.dotfiles/nixos-modules/hyprland/theme.nix)
  System-side desktop realization such as Qt and console colors.

- [`home-modules/programs/code/default.nix`](/home/axelcool1234/.dotfiles/home-modules/programs/code/default.nix)
  Example of a manual app-specific template realization.

- [`home-modules/terminal/lazygit/default.nix`](/home/axelcool1234/.dotfiles/home-modules/terminal/lazygit/default.nix)
  Example of merging a fetched upstream theme asset with a small generated base config.

## Catppuccin Notes

[`families/catppuccin.nix`](/home/axelcool1234/.dotfiles/themes/families/catppuccin.nix)
is the reference implementation for the current model.

It intentionally prefers upstream assets where they exist:

- `starship` from `catppuccin/starship`
- `lazygit` from `catppuccin/lazygit`
- `fzf` from `catppuccin/fzf`
- `hyprland` from `catppuccin/hyprland`
- `yazi` from `catppuccin/yazi`
- `yazi` syntect theme from `catppuccin/bat`
- `grub` from `catppuccin/grub`

The only intentional manual app right now is `code`, because there is no widely used
upstream Catppuccin config asset for it in the same way as the others.

Other notable current choices:

- Wlogout still uses a local generated palette fragment because the wrapper expects a
  tiny `@define-color` file rather than the full upstream stylesheet. The reason for
  this is because it looks nicer.

## Adding An App

When adding a new app or cleaning up an old one, use this order:

1. Check whether upstream already ships a stable Catppuccin asset.
2. If yes, prefer `asset`, `asset+import`, or `package`.
3. If no, decide whether the app can consume structured options from a module.
4. Only fall back to `template` when the app really needs a small local generated config.
5. Keep app-only values in `provider.options`, not in `data`.

## Troubleshooting

- If `resolveAssetSource` returns `null`, check that the GitHub package reference has a
  pinned `rev`.

- If Home Manager activation fails because a user file already exists, prefer merging or
  narrowly managing only the themed fragment instead of clobbering the whole file.

- If a wrapper starts looking more important than the imported asset, that is a sign the
  provider split is wrong and should be revisited.

- If a field in `data` only exists to support one app, it should probably be removed and
  moved into that app's `provider.options`.

## Cleanup Rules

When touching this system, prefer these rules:

- If an app can use a stable upstream asset, prefer that over duplicating local theme data.
- If a value is only consumed by one app, keep it on that app's provider options.
- Keep `data` small and shared.
- Keep wrappers tiny. If a wrapper starts carrying the real theme logic, that's probably
a bad sign.
