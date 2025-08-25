(require (prefix-in helix. "helix/components.scm"))
(require (prefix-in helix. "helix/static.scm"))
(require (prefix-in helix. "helix/editor.scm"))
(require (prefix-in helix. "helix/misc.scm"))
(require (prefix-in keymaps. "./keymaps.scm"))

(require "./data.scm")
(define abbrev-names (transduce abbrev-pairs (mapping first) (into-list)))
(define abbrev-lookup (transduce abbrev-pairs (into-hashmap)))

(define max-abbrev-length (transduce abbrev-names (mapping string-length) (into-reducer max 0)))
(define max-results 10)

(define (abbrev-matches input)
  (transduce abbrev-names (filtering (lambda (x) (starts-with? x input))) (taking max-results) (into-list))
)

(define (state-new) (mutable-vector ""))
(define (state-input st) (mut-vector-ref st 0))
(define (state-mut-input st f) (vector-set! st 0 (f (mut-vector-ref st 0))))

(define (render st _ buf)
  (define width max-abbrev-length)
  (define height (+ 1 max-results))
  (define cursor (first (helix.current-cursor)))
  (define x (helix.position-col cursor))
  (define y (+ 1 (helix.position-row cursor)))
  (define rect (helix.area x y width height))
  (define style (helix.theme-scope "ui.popup"))
  (helix.buffer/clear-with buf rect style)
  (define input (state-input st))
  (helix.buffer/clear-with buf (helix.area x y (+ 1 (string-length input)) 1) (helix.style-underline-style style helix.Underline/Line))
  (helix.widget/list/render buf rect (helix.widget/list
    (cons
      (string-append "\\" input)
      (abbrev-matches input)
    )
  ))
)

(define (str-push c) (lambda (x) (string-append x (string c))))
(define (str-pop x) (substring x 0 (max 0 (- (string-length x) 1))))

(define (handle st event)
  (define input (state-input st))
  (define char (helix.key-event-char event))
  (cond
    ((helix.key-event-escape? event) helix.event-result/close)
    ((and (eq? input "") (eq? char #\\))
      (helix.insert_string "\\")
      helix.event-result/close
    )
    ((or (eq? char #\ ) (helix.key-event-enter? event))
      (define results (abbrev-matches input))
      (if (not (empty? results))
        (helix.insert_string (hash-get abbrev-lookup (first results)))
      )
      helix.event-result/close
    )
    ((helix.key-event-char event)
      (state-mut-input st (str-push char))
      helix.event-result/consume
    )
    ((helix.key-event-backspace? event)
      (state-mut-input st str-pop)
      helix.event-result/consume
    )
    (#true helix.event-result/consume-without-rerender)
  )
)

(define functions (hash
  "handle_event" handle
))

(define (component) (helix.new-component! "Abbreviation" (state-new) render functions))

(provide abbreviation)
(define (abbreviation) (helix.push-component! (component)) )

(define global-keys (hash "insert" (hash "C-\\" ':abbreviation)))
(define lang-keys (hash "insert" (hash "\\" ':abbreviation)))

(provide abbreviations-configure)
(define (abbreviations-configure langs)
  (keymaps.add-global-keybinding global-keys)
  (define lang-keymap (keymaps.deep-copy-global-keybindings))
  (keymaps.merge-keybindings lang-keymap lang-keys)
  (keymaps.set-global-buffer-or-extension-keymap
    (transduce langs (mapping (lambda (lang) (list lang lang-keymap))) (into-hashmap))
  )
)

