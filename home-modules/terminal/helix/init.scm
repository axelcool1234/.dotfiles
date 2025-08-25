; init.scm
(require "helix-abbreviations/abbrevs.scm")
(require "helix/configuration.scm")

(abbreviations-configure (list "lean"))

(define-lsp "steel-language-server" (command "steel-language-server") (args '()))
(define-language "scheme"
                 (language-servers '("steel-language-server")))