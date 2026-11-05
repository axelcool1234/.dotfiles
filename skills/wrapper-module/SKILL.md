---
name: wrapper-module
description: Use when creating or refactoring a wrapper under `wrappers/`, especially when a generic `module.nix` should follow the idioms used in `BirdeeHub/nix-wrapper-modules`, or when auditing an existing wrapper module for non-idiomatic structure.
metadata:
  short-description: Create or audit a wrapper module
---

# Wrapper Module

Use this skill when the task is to create, split, refactor, or audit a wrapper
under `wrappers/` so it matches the style of
`BirdeeHub/nix-wrapper-modules` as closely as practical.

This skill is not for generic package wrapping advice. It is specifically for
wrapper modules in this dotfiles repo that are evaluated through the local
`wrapper-modules` input.

## When To Use This Skill

Use this skill when:

- a wrapper under `wrappers/` needs a new generic `module.nix`
- an existing wrapper should be split into generic `module.nix` plus local
  `default.nix`
- a wrapper audit needs to compare local patterns against Birdee's upstream
  idioms before changing code
- the task involves deciding whether runtime bootstrap belongs in generic
  wrapper logic or only in repo-local instantiation

## Core Goal

Produce or audit a wrapper so that:

- `module.nix` is a generic reusable wrapper module
- `default.nix` is the local instantiation layer for this repo
- helper-module idioms from `nix-wrapper-modules` are used where appropriate
- host-specific policy and repo-specific persistence stay out of the generic
  module unless they are truly generic to the wrapped application

If `module.nix` does not exist yet, create it.

If `module.nix` already exists, audit it first and prefer the smallest set of
changes that make it more idiomatic.

## Sources To Study First

Do not start coding from memory. Inspect the upstream docs and multiple existing
wrapper modules first.

Before anything else, read `CONTRIBUTING.md`. Treat it as mandatory. It
contains the core rules for adding wrapper modules versus helper modules,
required metadata, placeholder guidance, test expectations, and repo-level
module conventions.

Bias strongly toward deeper repo study before local edits. If browsing the docs
or reading a few files is not enough to understand the repeated idioms, feel
free to clone or otherwise inspect the `BirdeeHub/nix-wrapper-modules` repo more
thoroughly before continuing. A longer upstream study phase is preferred over a
fast but shallow local refactor.

Always inspect:

- <https://github.com/BirdeeHub/nix-wrapper-modules/blob/main/CONTRIBUTING.md>
- <https://birdeehub.github.io/nix-wrapper-modules/>
- <https://birdeehub.github.io/nix-wrapper-modules/md/getting-started.html>
- <https://birdeehub.github.io/nix-wrapper-modules/md/helper-modules.html>
- <https://github.com/BirdeeHub/nix-wrapper-modules/tree/main/wrapperModules>

Also inspect several real wrapper modules, not just one. Prefer a mix of simple
and complex examples.

Recommended baseline set:

- `wrapperModules/g/git/module.nix`
- `wrapperModules/h/helix/module.nix`
- `wrapperModules/y/yazi/module.nix`
- `wrapperModules/n/nushell/module.nix`
- `wrapperModules/o/opencode/module.nix`
- `wrapperModules/c/claude-code/module.nix`
- `wrapperModules/n/noctalia-shell/module.nix`
- `templates/neovim/README.md`

Also inspect helper-module implementations when relevant:

- `modules/default/module.nix`
- `modules/constructFiles/module.nix`
- `modules/makeWrapper/module.nix`

Do not skimp on this step. The point of this skill is to learn the repeated
idioms from several upstream modules before changing local code.

If needed, expand the study set beyond the baseline list. It is completely fine
to spend significant time reading the upstream codebase before doing any local
module construction or audit work.

Use `CONTRIBUTING.md` as the authoritative upstream rules document, not just a
contribution checklist. It is the main reference for wrapper-vs-helper module
boundaries, maintainer expectations, `check.nix` tests, placeholders, and
naming conventions. Use `templates/neovim/README.md` as an example of how
Birdee explains a wrapper module to downstream users and how examples can
clarify the intended module shape.

Treat naming as part of the audit, not just behavior. When a local option,
generated artifact, helper script, passthru value, or config shape has a close
parallel in Birdee's repo, explicitly check whether the local name should match
the upstream name. Only keep a different name when there is a concrete
application-driven or repo-driven reason for the divergence.

Treat upstream defaults as part of the audit too. When a local option or
generated config has a close upstream parallel, explicitly compare the default
value as well as the name and behavior. If the local default differs, keep that
difference only when there is a concrete application-driven or repo-driven
reason for it.

Treat implementation shape as part of the audit too. When a local option,
generated artifact, helper script, or runtime bootstrap step has a close
upstream parallel, compare how both sides are implemented, not just what they
do. If the local implementation differs, keep that difference only when there
is a concrete application-driven or repo-driven reason for it.

For this local dotfiles repo, treat missing `meta.maintainers` as acceptable
during audits unless the user explicitly wants strict upstream-ready parity.

For this local dotfiles repo, treat missing `check.nix` as acceptable during
audits unless the user explicitly wants strict upstream-ready parity or asks
for stronger repeated validation guidance.

## Study The Wrapped Program Too

Do not infer the wrapped program's behavior only from existing wrapper modules.
Before designing or auditing `module.nix`, study the application itself so the
wrapper matches the program's real configuration model and edge cases.

Prefer primary sources in roughly this order:

- official docs and examples
- the program's `--help`, man page, or built-in docs
- the upstream repository README, docs, and example configs
- the source tree when docs are vague or incomplete
- broader web search only when the primary sources still leave important gaps

If the docs are too shallow, it is fine to clone the upstream repo or otherwise
inspect it locally before continuing.

When possible, run or inspect the program/package enough to answer:

- is configuration expressed as TOML, JSON, YAML, KDL, Lua, CLI flags, env
  vars, or a mix?
- what config file names and search paths does the app actually support?
- can config be pointed elsewhere with a flag or env var such as `--config`?
- does the app merge multiple config files, include other files, or expect one
  monolithic file?
- which settings are naturally generated as files versus exposed as wrapper
  flags or env vars?
- does the app rewrite its config, create state on first launch, or require
  writable runtime directories?
- are plugins, themes, or extensions discovered from paths that should become
  options or generated artifacts?
- are there known edge cases, bootstrapping steps, or runtime assumptions that
  affect whether `constructFiles` is enough or whether a minimal `runShell` is
  justified?

Do not guess on config shape. If you cannot tell how the application is
configured, pause and inspect more of the app itself before writing the module.

## Local Files To Inspect

Inspect at minimum:

- `wrappers/<name>/default.nix` or `wrappers/<name>.nix`
- `wrappers/<name>/module.nix` if present
- `lib/default.nix`
- `wrappers/<name>/check.nix` if present

When needed, inspect sibling wrappers in this repo that already use similar
patterns.

## What To Look For

### In upstream modules

Look for repeated structure and naming patterns such as:

- `imports = [ wlib.modules.default ];` inside `module.nix`
- `package = lib.mkDefault ...` in the generic module
- small `let` blocks used only when they improve clarity
- generic options in `options = { ... };`
- `constructFiles` for generated files and helper scripts
- `env`, `envDefault`, `flags`, `flagSeparator`, `overrides`, and `passthru`
- optional outputs like `generatedConfig.output` or placeholders when a module
  exposes generated artifacts
- `meta.maintainers` and `meta.description` structure
- `check.nix` usage when the upstream module has non-trivial generated output,
  while remembering that this local repo may intentionally omit `check.nix`
- `runShell` only when the app genuinely needs runtime bootstrap or out-of-store
  copying, not as the first choice

### In the wrapped program itself

Look for the program's native configuration model, including:

- actual file format and schema shape
- default config locations and XDG behavior
- config override flags and environment variables
- whether config is read-only or rewritten by the app
- plugin/theme/extension discovery rules
- runtime state directories, caches, sockets, logs, or lockfiles
- example configs that show which settings map cleanly to Nix options
- tricky behavior that should stay in `default.nix` versus generic behavior that
  belongs in `module.nix`
- whether a runtime directory is a shared mutable root or a dedicated subtree
  that a wrapper can safely own

### In local modules under audit

Look for things that feel out of place compared to upstream modules, including:

- host-specific logic in `module.nix`
- theming-system references in `module.nix`
- persistence in `module.nix`
- personal defaults in `module.nix`
- option names that are less clear than upstream naming patterns
- generated artifacts that should be expressed through `constructFiles`
- bespoke shell logic that should instead be a generated helper script
- generic logic that takes ownership of a whole mutable runtime root when it
  should only own a dedicated subdirectory
- `default.nix` doing too little or too much

For each option in the local wrapper, explicitly ask:

- what is the closest parallel in Birdee's repo for this option or behavior?
- if there is a close upstream parallel, should the local name match that
  upstream name, and if not, what specific reason justifies the difference?
- if there is a close upstream parallel, should the local default match the
  upstream default, and if not, what specific reason justifies the difference?
- if there is a close upstream parallel, should the local implementation follow
  the same upstream shape, and if not, what specific reason justifies the
  difference?
- if there is no direct parallel, is there an adjacent upstream pattern that
  should be mirrored instead, such as `settings`, `extraSettings`, generated
  file outputs, placeholders, flags, env vars, passthru values, or app-specific
  runtime bootstrap like `outOfStoreConfig`?
- if there is still no good parallel, is there a strong application-driven
  reason this option must exist in this repo, rather than being removed,
  renamed, moved to `default.nix`, or expressed through a more upstream-like
  option?

Do not accept novel local options too quickly. If an option seems unique, spend
more time exploring the upstream `wrapperModules/` tree to find the nearest
pattern before deciding the local design is justified.

## Audit Workflow

If `module.nix` already exists, do this before editing:

1. Study the upstream docs and several wrapper modules.
2. Study the wrapped program's own docs, config format, and runtime behavior.
3. Read the local `default.nix` and `module.nix`.
4. List what is already idiomatic.
5. List what is out of place compared to upstream patterns or the app's real
   behavior.
6. For each local option, identify the closest upstream parallel or note that
   none was found after additional repo study.
7. For options without a clear parallel, justify why they must exist and why a
   more upstream-like pattern would not cover the need.
8. Prefer the smallest refactor that fixes the largest structural mismatch.

Questions to answer:

- Should this logic live in `module.nix` or `default.nix`?
- Should this be an option, a `constructFiles` entry, a `flag`, an `env`, or a
  `passthru` value?
- Is the option naming aligned with upstream patterns?
- Are the option defaults aligned with upstream patterns?
- Is the implementation shape aligned with upstream patterns?
- If there is an upstream parallel, is the local naming aligned with that exact
  upstream name, and if not, is the reason for divergence strong enough to keep
  it?
- If there is an upstream parallel, is the local default aligned with the exact
  upstream default, and if not, is the reason for divergence strong enough to
  keep it?
- If there is an upstream parallel, is the local implementation aligned with
  the exact upstream shape, and if not, is the reason for divergence strong
  enough to keep it?
- For each option, what is the nearest Birdee precedent, and if there is none,
  what is the concrete reason this repo needs to diverge?
- Is `runShell` actually necessary here, or is the app able to read generated
  config directly?
- If `runShell` is necessary, can it be reduced to calling a generated helper?
- If runtime files must be mirrored out of the store, which exact paths does the
  wrapper own, and which paths must remain shared mutable state?

## Creation Workflow

If building a new wrapper or splitting one file into `default.nix` and
`module.nix`, follow this structure unless the app clearly needs something else.

### 1. Make `module.nix` generic

Put generic application behavior here:

- reusable options
- generated config and helper scripts
- `package = lib.mkDefault ...`
- `env`, `envDefault`, `flags`, `flagSeparator`, `overrides`
- `passthru` values tied to generated artifacts
- config generation that matches the app's real native format and load path

Do not put these in `module.nix` unless they are app-generic:

- host-specific logic
- Noctalia-specific paths or theme fragments
- repo-specific persistence policy
- personal defaults that are not intrinsic to the wrapped app

### 2. Make `default.nix` the local instantiation layer

Put repo-local policy here:

- selected defaults
- discovered local resources
- theme fragment wiring
- persistence policy
- host-specific branching

### 3. Prefer helper-module idioms

Use upstream-style patterns in this order:

- `constructFiles` for generated files and generated helper scripts
- `flags` for direct program flags
- `env` or `envDefault` when the app supports environment-based configuration
- `passthru` for exposing generated artifacts to other wrappers or packages
- `runShell` only when the app requires mutable out-of-store state at runtime

Choose among these based on how the app itself works, not only on wrapper taste.
For example, a tool with a first-class TOML config file often wants
`constructFiles`, while a CLI-oriented tool may be cleaner with flags and env.
If the app rewrites files or bootstraps state on launch, account for that
explicitly instead of forcing a purely static pattern.

Quick decision guide:

- choose `env` or `envDefault` when the app already supports a stable env var
  for config or discovery
- choose `flags` when the app's native interface is primarily CLI-driven and
  the values map cleanly to arguments
- choose `constructFiles` when the app expects real config files, plugin/theme
  files, helper scripts, or other generated artifacts on disk
- choose `runShell` only when the app truly needs mutable runtime bootstrap or
  an out-of-store copy step that cannot be replaced by direct store paths

### 4. Model out-of-store runtime state explicitly

If the wrapped app needs writable runtime state, look at
`wrapperModules/n/noctalia-shell/module.nix` as the main reference.

Prefer options shaped like:

- writable runtime directory option
- auto-copy or auto-sync toggle
- generated helper script in `constructFiles`
- minimal `runShell` that only invokes that helper

But do not stop there. Also decide what the wrapper is allowed to own.

- Prefer owning a dedicated generated subtree inside a mutable runtime root
- Avoid claiming an entire shared runtime directory unless the app clearly
  treats that directory as wrapper-owned config
- If a resource tree is discoverable recursively by the app, a dedicated
  subdirectory is often safer than writing directly at the shared root

The goal is to keep declarative assets declarative without deleting or
shadowing unrelated user-managed runtime state.

## Tests And Validation

Use upstream guidance from `CONTRIBUTING.md` when deciding how to validate the
wrapper, but do not treat missing `check.nix` as an audit failure in this local
dotfiles repo unless the user explicitly wants stricter upstream parity.

When editing or creating a wrapper, prefer to finish with some combination of:

- `nix eval` to confirm the wrapper evaluates
- `nix build` of the wrapped package or a generated helper/config path
- inspection of generated files or helper scripts in the built output
- `check.nix` updates or additions when the wrapper has meaningful generated
  behavior worth testing repeatedly, when the user wants that level of coverage

If the wrapper generates more than one file, creates helper scripts, or manages
directory-shaped resources, actively inspect upstream `check.nix` files for
similar modules before deciding how to validate it.

If the app can validate config at runtime, prefer an executable test over a
string-content-only test.

## Output Guidance

When the task is an audit, the output should be easy to act on.

Prefer this shape:

1. findings ordered by severity
2. short note on what is already idiomatic
3. the smallest refactor or follow-up that would improve the wrapper most

Each finding should answer:

- what is wrong or questionable
- why it differs from Birdee's idioms or the app's real behavior
- whether it belongs in `module.nix` or `default.nix` instead

## Naming Guidance

When renaming or adding options, prefer names that mirror upstream patterns.

Examples of good directions:

- `generatedConfig.output`
- `generatedConfig.placeholder`
- `outOfStore...`
- `autoCopy...` or `autoSync...`
- `settings`
- `configFile`
- `pluginDirs`

Avoid vague or ad hoc names unless the app itself forces them.

## Completion Checklist

- [ ] Studied the upstream docs and multiple wrapper modules first
- [ ] Studied `CONTRIBUTING.md` for module boundaries, placeholders, and tests
- [ ] Studied `templates/neovim/README.md` or another upstream example that
  shows how Birdee explains a wrapper module to downstream users
- [ ] Studied the wrapped program's own docs, config model, and runtime behavior
- [ ] Inspected local `default.nix` and `module.nix`
- [ ] Inspected `check.nix` when present or consciously accepted its absence for
  this repo
- [ ] `module.nix` is generic and reusable
- [ ] `default.nix` holds local instantiation and repo policy
- [ ] `constructFiles` is used for generated artifacts where appropriate
- [ ] `runShell` is absent unless truly needed, or reduced to a generated helper
- [ ] Mutable runtime ownership was checked so the wrapper does not claim more
  of the runtime tree than it should
- [ ] Option names and structure were audited against upstream idioms
- [ ] Any persistence or theme-specific logic lives outside the generic module unless justified
