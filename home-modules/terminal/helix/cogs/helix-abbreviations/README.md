## `helix-abbreviations`

A small Helix plugin implementing [Lean unicode abbreviations](https://leanprover-community.github.io/glossary.html#unicode-abbreviation).

Requires the under-development [Steel-based plugin system](https://github.com/helix-editor/helix/pull/8675) for Helix.

Register the `:abbreviation` command:

```scheme
; helix.scm
(require "helix-abbreviations/abbrevs.scm")
(provide abbreviation)
```

Configure `C-\` to insert abbreviations anywhere, and `\` to insert abbreviations in Lean files:

```scheme
; init.scm
(require "helix-abbreviations/abbrevs.scm")
(abbreviations-configure (list "lean"))
```
