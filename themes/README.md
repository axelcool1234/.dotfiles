# Themes

`themes/` is the theme library for this dotfiles repo.

The key design idea is:

- `themeLib` is the library and API for defining and consuming themes.
- `theme` is the selected concrete theme bundle for the current system.

Theme family files do not directly configure programs. They describe theme data and
per-app delivery strategies. NixOS and Home Manager modules outside this directory then
realize that data into package selections, generated config files, and copied upstream
assets.

## Mental Model

At a high level, the flow is:

```text
themeLib
  -> theme family
  -> selected theme bundle
  -> runtime-enriched theme object
  -> consumer modules
  -> concrete config files and packages
```

In this repo:

- `themeLib`
  The imported library from `./themes`.

- `theme`
  The selected bundle, enriched with runtime helpers such as `theme.providerFor` and
  `theme.resolveAssetSource`.

- `theme.apps.<name>.provider`
  The delivery record for one app.

So the library is intentionally split into:

- declaration APIs for building theme data
- internal theme math and bundle helpers
- provider resolution helpers
- runtime access helpers bound to one selected theme

## Definitions

These are the most important terms used throughout this library.

- `themeLib`
  The global theme library imported from `./themes`.

- `theme`
  The selected concrete theme bundle, usually enriched with `withRuntime` before it is
  passed to consumer modules.

- `family`
  A theme family implementation such as Catppuccin or Tokyo Night.

- `source`
  The family-selection record describing which member of a family was chosen, such as
  `variant = "mocha"` or `accent = "teal"`.

- `app`
  The logical theme target identified by a key under `theme.apps`, such as `"gtk"`,
  `"waybar"`, `"spicetify"`, or `"grub"`.

- `app record`
  The full record stored under `theme.apps.<name>`, usually containing `enable`,
  `provider`, and optional notes.

- `provider`
  The delivery record stored under `theme.apps.<name>.provider`. It describes how one
  app receives its theme.

- `options`
  The provider-specific payload consumed by the realizer or consumer module for that
  provider.

- `consumer`
  A module outside `themes/` that takes the selected `theme`, reads one or more app
  providers from it, and consumes that bundle data to produce concrete results such as
  generated config files, copied assets, package selections, or module options. In this
  repo, consumer modules primarily live under `home-modules/` and `nixos-modules/`.

The short version is:

```text
app = what thing is being themed?
provider = how does that thing receive its theme?
```

## Directory Structure

- [`default.nix`](/home/axelcool1234/.dotfiles/themes/default.nix)
  Public entrypoint for the library. The intended top-level API is:
  `families`, `stylix`, and `withRuntime`.

- [`constructors.nix`](/home/axelcool1234/.dotfiles/themes/constructors.nix)
  Pure constructors for theme bundles, theme sources, providers, app records, and
  GitHub-backed package descriptors.

- [`internal.nix`](/home/axelcool1234/.dotfiles/themes/internal.nix)
  Theme-internal helpers such as palette access and rgba conversion.

- [`resolvers.nix`](/home/axelcool1234/.dotfiles/themes/resolvers.nix)
  Helpers that turn provider descriptors into concrete files or paths.

- [`accessors.nix`](/home/axelcool1234/.dotfiles/themes/accessors.nix)
  Runtime helpers bound to one selected `theme`, such as `providerFor`,
  `requireModuleOption`, and `providerWrapperFile`.

- [`families/`](/home/axelcool1234/.dotfiles/themes/families)
  Theme family implementations such as Catppuccin and Tokyo Night.

- [`stylix.nix`](/home/axelcool1234/.dotfiles/themes/stylix.nix)
  Builder for Stylix-backed theme bundles, where the bundle only needs to describe the
  custom apps this repo still manages locally.

- [`wrappers/`](/home/axelcool1234/.dotfiles/themes/wrappers)
  Small local wrapper configs that import upstream assets or generated fragments.

## Top-Level API

Import the library and choose a theme family:

```nix
let
  themeLib = import ./themes { inherit lib; };

  theme = themeLib.withRuntime (themeLib.families.catppuccin.mk {
    source = {
      variant = "mocha";
      accent = "teal";
    };
  });
in
{
  # Pass `theme` through flake specialArgs.
}
```

In the current flake, `themeLib` stays local to `flake.nix` and is used to build the
selected `theme`. Consumer modules only receive `theme`.

`themeLib` intentionally exposes:

- `families`
- `stylix`
- `withRuntime`

`withRuntime` takes a plain theme bundle and returns a runtime-enriched `theme` object.

That runtime object keeps the original theme bundle shape and also adds helper methods
used by consumer modules.

The lower-level files under `themes/` (such as `accessors.nix` and `resolvers.nix`) still
exist as internal structure for better maintenance, but they are not the main public API
of the library. The idea is a user constructs a theme bundle with `families`, enriches
it with `withRuntime`, and then passes around the resulting `theme` runtime object to
consumers.

Stylix is intentionally modeled separately from `families`. In Stylix mode, most apps
are expected to be themed automatically by Stylix itself, and the bundle typically only
defines the custom exceptions that this repo still wants to manage locally.

## Theme Bundle Shape

Before runtime enrichment, a theme bundle has this shape:

```nix
{
  meta = { ... };
  source = { ... };
  apps = { ... };
  data = { ... };
}
```

- `meta`
  Human-oriented metadata like family title and title-cased names.

- `source`
  The selected theme source, such as `family = "catppuccin"`,
  `variant = "mocha"`, `accent = "teal"`, `mode = "dark"` for family themes,
  or `type = "stylix"` plus a concrete `base16Scheme` path for Stylix themes.

- `apps`
  Per-app theme delivery records.

- `data`
  Small shared derived values that are still useful outside individual app records.

For example, the current Stylix builder stores concrete shared values such as:

- `data.raw`
  Parsed Base16 colors from the selected scheme file.

- `data.palette`
  The semantic palette derived from `data.raw` and reused by custom app providers.

As a rule of thumb:

- if a value is only used by one app, keep it on that app's provider/options
- if several consumers need it, keep it in `data`
- if upstream already ships the file you need, prefer an asset over derived data

## Runtime Theme Shape

After `themeLib.withRuntime`, the selected `theme` still has `meta`, `source`, `apps`,
and `data`, but also gains runtime helpers.

Common examples:

- `theme.providerFor "starship"`
  Returns the enabled provider for one app, or `null`.

- `theme.providerOption provider "colors"`
  Reads one provider option. Most runtime access helpers accept either an app name or
  an already-bound provider value.

- `theme.requireModuleOption "gtk" "themeName"`
  Reads one required option from a module-backed provider or throws.

- `theme.requireModuleOption gtkProvider "themeName"`
  The same helper also accepts a provider directly when that provider is already in
  scope.

- `theme.resolveAssetSource "grub"`
  Resolves an app's provider into an upstream asset path, or returns `null`.

- `theme.resolveWrapperText provider`
  Reads the wrapper file contents for an asset+import provider, or returns `null`.

- `theme.isStylix`
  Indicates that the selected runtime theme was built from `themeLib.stylix.mk`.

- `theme.isHandledByStylix "helix"`
  Indicates that an app is absent from the current Stylix bundle and should therefore be
  treated as owned by Stylix rather than by this repo's local consumers.

In other words, in Stylix mode a missing app provider usually means:

```text
this repo does not manage that app here
Stylix is expected to handle it instead
```

The runtime theme is the thing consumer modules should normally use.

### Runtime Helper Input Style

Most runtime helpers are overloaded to accept either:

- an app key like `"grub"`
- or an already-bound provider such as `grubProvider`

Rule of thumb:

- if you do not already have the provider, pass the app name
- if you already have the provider in scope, pass the provider to avoid resolving it a
  second time

Examples:

```nix
theme.resolveAssetSource "grub"
theme.resolveAssetSource grubProvider

theme.requireModuleOption "gtk" "themeName"
theme.requireModuleOption gtkProvider "themeName"

theme.providerOption "waybar" "colors"
theme.providerOption waybarProvider "colors"
```

## Family API

A family under `themeLib.families` is not itself the final bundle. It is a small API
for building one.

The intended public family exports are:

- `mk`
  Build a final theme bundle.

- `meta`
  Family-level metadata such as the family id and title.

- So the public family shape is intentionally small:

```nix
{
  meta = { ... };
  mk = ...;
}
```

Family files may still contain lower-level helpers like `mkSource`, `mkApps`, and
`mkData` internally as implementation structure, but those are not part of the intended
public API.

So the expected usage is:

```nix
theme = themeLib.withRuntime (themeLib.families.catppuccin.mk {
  source = {
    variant = "mocha";
    accent = "teal";
  };
});
```

The family internals remain free to change as long as `mk` continues to return the same
theme bundle shape.

## Stylix API

Stylix is a separate top-level builder, not a family.

The intended public Stylix API is:

- `themeLib.stylix.mk`
  Build a Stylix-backed theme bundle.

- `themeLib.stylix.meta`
  Stylix-specific metadata.

Typical usage:

```nix
let
  pkgs = import nixpkgs {
    inherit system;
  };
in
theme = themeLib.withRuntime (themeLib.stylix.mk {
  source.base16Scheme = "${pkgs.base16-schemes}/share/themes/rose-pine-moon.yaml";
});
```

In the current flake, the Stylix theme is built per-system so it can use the concrete
`${pkgs.base16-schemes}/share/themes/...` path for `source.base16Scheme`.

In this mode:

- Stylix is expected to handle most supported apps automatically
- the bundle usually only defines the custom apps you still want this repo to manage
- consumers should no-op when `theme.isHandledByStylix input` is true
- a missing app provider is treated as "Stylix-owned" rather than as an error

## App Delivery Records

Each entry under `theme.apps` has this general shape:

```nix
{
  enable = true;
  provider = { ... };
  notes = [ ... ];
}
```

The provider says how that app receives its theme.

### Provider Kinds

These are the current provider kinds used by the library and by the realizing modules.

- `module`
  A consumer module reads structured options from the provider.

- `package`
  The app wants a package or plugin from a package set.

- `asset`
  Copy or link one upstream asset file or directory.

- `asset+import`
  Use an upstream asset plus a small local wrapper file.

- `template`
  Generate text from provider options.

- `custom`
  Reserved for fully custom local-file-backed handling.

### Source Kinds

Theme bundles also carry a top-level `source.type`.

- `family`
  A source selected from a known family.

- `stylix`
  A top-level source produced by `themeLib.stylix.mk`.

## Library Layer Responsibilities

This is the intended boundary between the main files in `themes/`.

### `constructors.nix`

Use this layer when you are:

- building bundle records
- building provider records
- building source records

Do not put runtime bundle access or file resolution logic here.

### `internal.nix`

Use this layer for:

- palette helpers
- bundle-internal helper logic
- conversions like `getRgba`

This layer is mostly for misc such as family implementations
and low-level theme internals.

### `resolvers.nix`

Use this layer for:

- turning provider descriptors into concrete asset paths
- reading wrapper-file text

This layer is provider-oriented, not theme-selection-oriented.

### `accessors.nix`

Use this layer for:

- reading from one selected `theme`
- checking whether apps are enabled
- reading required provider options
- finding wrapper files

This layer is for runtime consumption of a selected theme bundle.

### `withRuntime`

Use this when you want the ergonomic runtime API on `theme`.
You can't do much without it.

It currently composes:

- accessor helpers bound to the selected theme
- resolver helpers bound as convenience methods on the selected theme

## Consumer Side

Modules outside `themes/` should usually consume:

- `theme`
  for runtime access like `theme.providerFor` or `theme.resolveAssetSource`

That means most modules should prefer:

```nix
provider = theme.providerFor "starship";
source = theme.resolveAssetSource provider;
```

or, when the provider is not needed separately:

```nix
source = theme.resolveAssetSource "grub";
```

And similarly for required options:

```nix
themeName = theme.requireModuleOption "gtk" "themeName";
```

or, if the provider is already needed for nearby logic:

```nix
gtkProvider = theme.providerFor "gtk";
themeName = theme.requireModuleOption gtkProvider "themeName";
```

In the current flake setup, consumer modules only receive `theme`. `themeLib` stays
local to `flake.nix` and is used there to build the selected runtime theme only.

## Realization Layer

The theme library intentionally stops at theme data plus runtime helpers.

The actual writing of config files happens elsewhere, mainly in:

- [home-modules/theme/default.nix](/home/axelcool1234/.dotfiles/home-modules/theme/default.nix)
  Orchestrates theme realization into XDG files.

- [home-modules/theme/realizers.nix](/home/axelcool1234/.dotfiles/home-modules/theme/realizers.nix)
  Contains text/file realization helpers used by that module.

So the architecture is:

```text
themeLib
  -> families produce bundle data
  -> withRuntime enriches the selected bundle
  -> home-manager/nixos modules consume theme
  -> realizers materialize files
```

## Future Directions

The current split leaves room for future work without collapsing layers together:

- more families
- richer Stylix support for custom app consumers
- richer accessor helpers for module-heavy consumers
- more reusable realizers outside the main theme realizer module

The main rule is to keep responsibilities separate:

- declaration in `constructors`
- internal theme logic in `internal`
- provider resolution in `resolvers`
- selected-theme reads in `accessors`
- file generation in `home-modules/theme/realizers.nix`
