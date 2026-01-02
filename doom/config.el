;;; ~/.config/doom/config.el
(setq user-full-name "Lumi Denoir"
      user-mail-address "lumidenoir@gmail.com")

(setq doom-font (font-spec :family "Iosevka" :size 15 :weight 'regular :slant 'normal :width 'expanded :spacing 90)
      doom-big-font-mode (font-spec :family "Iosevka" :size 25)
      doom-variable-pitch-font (font-spec :family "Iosevka Etoile" :size 16)
      doom-emoji-font (font-spec :family "Noto Color Emoji")
      doom-symbol-font (font-spec :family "Iosevka")
      doom-serif-font (font-spec :family "IBM Plex Mono" :size 17 :weight 'light)
      doom-theme 'doom-one
      display-line-numbers-type nil)

;;HACK to replace evil keyword in which-key popup
(setq which-key-idle-delay 0.5)
(setq which-key-allow-multiple-replacements t)
(after! which-key
  (pushnew!
   which-key-replacement-alist
   '(("" . "\\`+?evil[-:]?\\(?:a-\\)?\\(.*\\)") . (nil . "◂\\1"))
   '(("\\`g s" . "\\`evilem--?motion-\\(.*\\)") . (nil . "◃\\1"))
   ))

;; Setting the directory for Org files and other related paths
(setq org-directory (file-truename "~/org/")
      org-hugo-base-dir (file-truename "~/Public/")
      org-noter-notes-search-path '("~/org/") ;; Path for org-noter notes
      org-hide-emphasis-markers t  ;; Hide markers like *, /, =, etc.
      org-log-done 'time) ;; Log the time when a TODO is marked as DONE
(add-hook 'org-mode-hook #'+org-pretty-mode)
;; Enable org-fragtog-mode for automatic LaTeX fragment toggling
(add-hook 'org-mode-hook 'org-fragtog-mode)
(setq org-startup-with-latex-preview t) ;; Start with LaTeX preview enabled
(setq org-cite-csl-styles-dir "/home/lumi/Zotero/styles") ;; Path to CSL styles for citations

(setq reftex-default-bibliography "/home/lumi/org/zotero.bib"
      org-agenda-files '("/home/lumi/org/todo.org" "/home/lumi/org/todoist.org")
      org-fold-catch-invisible-edits 'smart)
(after! org
  (setq org-adapt-indentation t)
  ;; Set some faces for various org elements
  (custom-set-faces!
    ;; Customize org-quote
    `((org-quote)
      :foreground ,(doom-color 'blue) :extend t :italic t)
    ;; Customize org-verse
    `((org-verse)
      :foreground ,(doom-color 'yellow)  :extend t :italic t))
  ;; Change how LaTeX and image previews are shown
  (setq org-highlight-latex-and-related '(native entities script)))
(setq org-src-window-setup 'current-window)

(setq org-src-fontify-natively t
      org-src-tab-acts-natively t
      org-edit-src-content-indentation 0)

(defun locally-defer-font-lock ()
  "Set jit-lock defer and stealth, when buffer is over a certain size."
  (when (> (buffer-size) 50000)
    (setq-local jit-lock-defer-time 0.05
                jit-lock-stealth-time 1)))
(add-hook 'org-mode-hook #'locally-defer-font-lock)

(setq org-agenda-deadline-faces
      '((1.001 . error)
        (1.0 . org-warning)
        (0.5 . org-upcoming-deadline)
        (0.0 . org-upcoming-distant-deadline)))


(after! org
;;Resize Org headings
(dolist (face '((org-level-1 . 1.4)
                (org-level-2 . 1.3)
                (org-level-3 . 1.2)
                (org-level-4 . 1.1)
                (org-level-5 . 1.1)
                (org-level-6 . 1.1)
                (org-level-7 . 1.1)
                (org-level-8 . 1.1)))
  (set-face-attribute (car face) nil :font "Iosevka Etoile" :weight 'bold :height (cdr face)))

;; Make the document title a bit bigger
  (set-face-attribute 'org-document-title nil :font "Alegreya" :weight 'bold :height 1.8))
(setq org-ellipsis " ▾ ")

(setq org-export-headline-levels 5) ; I like nesting

(defvar org-reference-contraction-max-words 3
  "Maximum number of words in a reference reference.")
(defvar org-reference-contraction-max-length 35
  "Maximum length of resulting reference reference, including joining characters.")
(defvar org-reference-contraction-stripped-words
  '("the" "on" "in" "off" "a" "for" "by" "of" "and" "is" "to" "as")
  "Superfluous words to be removed from a reference.")
(defvar org-reference-contraction-joining-char "-"
  "Character used to join words in the reference reference.")

(defun org-reference-contraction-truncate-words (words)
  "Using `org-reference-contraction-max-length' as the total character 'budget' for the WORDS
and truncate individual words to conform to this budget.

To arrive at a budget that accounts for words undershooting their requisite average length,
the number of characters in the budget freed by short words is distributed among the words
exceeding the average length.  This adjusts the per-word budget to be the maximum feasable for
this particular situation, rather than the universal maximum average.

This budget-adjusted per-word maximum length is given by the mathematical expression below:

max length = \\floor{ \\frac{total length - chars for seperators - \\sum_{word \\leq average length} length(word) }{num(words) > average length} }"
  ;; trucate each word to a max word length determined by
  ;;
  (let* ((total-length-budget (- org-reference-contraction-max-length  ; how many non-separator chars we can use
                                 (1- (length words))))
         (word-length-budget (/ total-length-budget                      ; max length of each word to keep within budget
                                org-reference-contraction-max-words))
         (num-overlong (-count (lambda (word)                            ; how many words exceed that budget
                                 (> (length word) word-length-budget))
                               words))
         (total-short-length (-sum (mapcar (lambda (word)                ; total length of words under that budget
                                             (if (<= (length word) word-length-budget)
                                                 (length word) 0))
                                           words)))
         (max-length (/ (- total-length-budget total-short-length)       ; max(max-length) that we can have to fit within the budget
                        num-overlong)))
    (mapcar (lambda (word)
              (if (<= (length word) max-length)
                  word
                (substring word 0 max-length)))
            words)))

(defun org-reference-contraction (reference-string)
  "Give a contracted form of REFERENCE-STRING that is only contains alphanumeric characters.
Strips 'joining' words present in `org-reference-contraction-stripped-words',
and then limits the result to the first `org-reference-contraction-max-words' words.
If the total length is > `org-reference-contraction-max-length' then individual words are
truncated to fit within the limit using `org-reference-contraction-truncate-words'."
  (let ((reference-words
         (cl-remove-if-not
          (lambda (word)
            (not (member word org-reference-contraction-stripped-words)))
          (let ((str reference-string))
            (setq str (downcase str))
            (setq str (replace-regexp-in-string "\\[\\[[^]]+\\]\\[\\([^]]+\\)\\]\\]" "\\1" str)) ; get description from org-link
            (setq str (replace-regexp-in-string "[-/ ]+" " " str)) ; replace seperator-type chars with space
            (setq str (puny-encode-string str))
            (setq str (replace-regexp-in-string "^xn--\\(.*?\\) ?-?\\([a-z0-9]+\\)$" "\\2 \\1" str)) ; rearrange punycode
            (setq str (replace-regexp-in-string "[^A-Za-z0-9 ]" "" str)) ; strip chars which need %-encoding in a uri
            (split-string str " +")))))
    (when (> (length reference-words)
             org-reference-contraction-max-words)
      (setq reference-words
            (cl-subseq reference-words 0 org-reference-contraction-max-words)))

    (when (> (apply #'+ (1- (length reference-words))
                    (mapcar #'length reference-words))
             org-reference-contraction-max-length)
      (setq reference-words (org-reference-contraction-truncate-words reference-words)))

    (string-join reference-words org-reference-contraction-joining-char)))

;; Set Deft to use the first non-empty line as the title, and specify the directory
(setq deft-use-filename-as-title nil
      deft-directory "~/org/")

;; Customize Deft's summary parsing to ignore org labels and properties
(setq deft-strip-summary-regexp
      (concat "\\("
              "[\n\t]" ;; blank
              "\\|^#\\+[[:alpha:]_]+:.*$" ;; org-mode metadata
              "\\|^:PROPERTIES:\n\\(.+\n\\)+:END:\n" ;; roam metadata
              "\\)"))

;; Function to parse the title in Deft, looking for #+TITLE: in the contents
(defun cm/deft-parse-title (file contents)
  (let ((begin (string-match "^#\\+[tT][iI][tT][lL][eE]: .*$" contents)))
    (if begin
        (string-trim (substring contents begin (match-end 0)) "#\\+[tT][iI][tT][lL][eE]: *" "[\n\t ]+")
      (deft-base-filename file))))

(advice-add 'deft-parse-title :override #'cm/deft-parse-title)

(setq org-todo-keywords
      '((sequence "TODO(t)" "PROJ(p)" "EVNT(e)" "STRT(s)" "WAIT(w)" "HOLD(h)" "REVI(r)" "IDEA(i)" "|" "DONE(d)" "KILL(k)")
        (sequence "[ ](T)" "[-](S)" "[?](W)" "|" "[X](D)")
        (sequence "|" "OKAY(o)" "YES(y)" "NO(n)")))

(setq org-todo-keyword-faces
      '(("[-]" . +org-todo-active)
        ("STRT" . +org-todo-active)
        ("[?]" . +org-todo-onhold)
        ("WAIT" . +org-todo-onhold)
        ("REVI" . +org-todo-onhold)
        ("HOLD" . +org-todo-onhold)
        ("EVNT" . +org-todo-project)
        ("PROJ" . +org-todo-project)
        ("NO" . +org-todo-cancel)
        ("KILL" . +org-todo-cancel)))

;; Set the directory for Org-roam files
(setq org-roam-directory (file-truename "~/org/"))

;; Define capture templates for Org-roam
(setq org-roam-capture-templates
    '(("d" "default" plain "%?" :target
       (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "#+TITLE:${title}\n#+filetags: :incomplete:\n#+DATE: %U\n#+EXPORT_FILE_NAME: ${slug}\n")
       :unnarrowed t)))

;; Configure timestamp format for Org-roam
(setq time-stamp-active t
      time-stamp-start "#\\+DATE:[ \t]*"
      time-stamp-end "$"
      time-stamp-format "\[%Y-%02m-%02d %3a %02H:%02M\]")
(add-hook 'before-save-hook 'time-stamp nil)

;; Display Org-roam buffer in a side window
(add-to-list 'display-buffer-alist
             '("\\*org-roam\\*"
               (display-buffer-in-side-window)
               (side . right)
               (slot . 0)
               (window-width . 0.33)
               (window-parameters . ((no-other-window . t)
                                     (no-delete-other-windows . t)))))

;; Define sections to display in Org-roam mode
(setq org-roam-mode-sections
      '((org-roam-backlinks-section :unique t)
        org-roam-reflinks-section))

(after! (org-roam nerd-icons-corfu)
  (add-to-list
   'nerd-icons-corfu-mapping
   '(org-roam :style "cod" :icon "symbol_interface" :face font-lock-type-face)))

(defadvice! doom-modeline--buffer-file-name-roam-aware-a (orig-fun)
  :around #'doom-modeline-buffer-file-name ; takes no args
  (if (string-match-p (regexp-quote org-roam-directory) (or buffer-file-name ""))
      (replace-regexp-in-string
       "\\(?:^\\|.*/\\)\\([0-9]\\{4\\}\\)\\([0-9]\\{2\\}\\)\\([0-9]\\{2\\}\\)[0-9]*-"
       "(\\1-\\2-\\3) "
       (subst-char-in-string ?_ ?  buffer-file-name))
    (funcall orig-fun)))

(use-package! websocket
  :after org-roam)

(use-package! org-roam-ui
  :after org-roam
  :config
  ;; Sync theme, follow the node in the graph, update on save, and open on start
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start t))

(defun date-three-days-later ()
  "Return the date three days from today in the format YYYY-MM-DD."
  (let* ((today (current-time))                         ;; Get the current time
         (three-days-later (time-add today (* 3 24 60 60))) ;; Add three days to current time
         (date-string (format-time-string "%Y-%m-%d" three-days-later))) ;; Format the new date
    date-string))

;; Calculate the date three days later and store it in a variable
(let ((date-three-days-later (date-three-days-later)))
  (setq org-agenda-custom-commands
        `(("c" "Super view"
           ((alltodo "" ((org-agenda-overriding-header "")
                         (org-super-agenda-groups
                          '((:name "Actionable Today"
                             :deadline today
                             :scheduled today
                             :face (:foreground "green")
                             :order 1)
                            (:name "Overdue"
                             :deadline past
                             :face (:foreground "red")
                             :order 2)
                            (:name "Deadline soon"
                                   :face (:foreground "orange")
                                   :deadline (before ,date-three-days-later)
                                   :order 3)
                            (:habit t)
                            (:name "Scheduled for Future"
                             :scheduled future
                             :face (:foreground "blue")
                             :order 4)
                            (:name "In Progress"
                             :todo ("STRT" "WAIT" "HOLD")
                             :and (:scheduled past :deadline future)
                             :order 5)
                            (:name "Not yet started"
                             :todo ("TODO" "PROJ" "IDEA")
                             :scheduled nil
                             :deadline nil
                             :order 6))))))))))

(use-package! org-super-agenda
  :after org-agenda
  :config
  (org-super-agenda-mode))

(use-package! org-modern
  :hook (org-mode . org-modern-mode)
  :config
  (setq
   ;; Edit settings
   org-fold-catch-invisible-edits 'show-and-error
   org-special-ctrl-a/e t
   org-insert-heading-respect-content t
   ;; Appearance
   org-modern-radio-target    '("❰" t "❱")
   org-modern-internal-target '("↪ " t "")
   org-modern-todo nil
   org-modern-tag t
   org-modern-star 'replace
   org-modern-block-name nil
   org-modern-timestamp nil
   org-modern-statistics nil
   org-modern-table nil
   org-modern-progress 12
   org-modern-priority nil
   org-modern-horizontal-rule "──────────"
   org-modern-keyword nil
   org-agenda-tags-column 0
   org-modern-list '((43 . "•")
                     (45 . "–")
                     (42 . "↪")))
  (custom-set-faces!
    ;; `((org-modern-tag)
    ;;   :background ,(doom-blend (doom-color 'blue) (doom-color 'bg) 0.1)
    ;;   :foreground ,(doom-color 'grey))
    `((org-modern-radio-target org-modern-internal-target)
      :inherit 'default :foreground ,(doom-color 'blue)))
  )

(use-package! org-appear
  :hook (org-mode . org-appear-mode)
  :config
  (setq org-appear-autoemphasis t
        org-appear-autosubmarkers t
        org-appear-autolinks nil)
  ;; for proper first-time setup, `org-appear--set-elements'
  ;; needs to be run after other hooks have acted.
  (run-at-time nil nil #'org-appear--set-elements))

(use-package! svg-tag-mode
  :config
  (defconst date-re "[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}")
  (defconst time-re "[0-9]\\{2\\}:[0-9]\\{2\\}")
  (defconst day-re "[A-Za-z]\\{3\\}")
  (defconst day-time-re (format "\\(%s\\)? ?\\(%s\\)?" day-re time-re))

  (defun svg-progress-percent (value)
    (save-match-data
    (svg-image (svg-lib-concat
                (svg-lib-progress-bar
                 (/ (string-to-number value) 100.0) nil
                 :height 0.8 :foreground (doom-color 'fg) :background (doom-color 'bg)
                 :margin 0 :stroke 2 :radius 3 :padding 2 :width 11)
                (svg-lib-tag (concat value "%") nil
                             :height 0.8 :foreground (doom-color 'fg) :background (doom-color 'bg)
                             :stroke 0 :margin 0)) :ascent 'center)))

(defun svg-progress-count (value)
  (save-match-data
    (let* ((seq (split-string value "/"))
           (count (if (stringp (car seq))
                      (float (string-to-number (car seq)))
                    0))
           (total (if (stringp (cadr seq))
                      (float (string-to-number (cadr seq)))
                    1000)))
      (svg-image (svg-lib-concat
                  (svg-lib-progress-bar (/ count total) nil
                                        :foreground (doom-color 'fg)
                                        :background (doom-color 'bg) :height 0.8
                                        :margin 0 :stroke 2 :radius 3 :padding 2 :width 11)
                  (svg-lib-tag value nil
                               :foreground (doom-color 'fg)
                               :background (doom-color 'bg)
                               :stroke 0 :margin 0 :height 0.8)) :ascent 'center))))

  (set-face-attribute 'svg-tag-default-face nil :family "Cartograph Sans CF")
  (setq svg-tag-tags
        `(;; Task priority e.g. [#A], [#B], or [#C]
          ("\\[#A\\]" . ((lambda (tag) (svg-tag-make tag :face 'error :inverse t :height .9
                                                     :beg 2 :end -1 :margin 0 :radius 10))))
          ("\\[#B\\]" . ((lambda (tag) (svg-tag-make tag :face 'warning :inverse t :height .9
                                                     :beg 2 :end -1 :margin 0 :radius 10))))
          ("\\[#C\\]" . ((lambda (tag) (svg-tag-make tag :face 'org-todo :inverse t :height .9
                                                     :beg 2 :end -1 :margin 0 :radius 10))))
          ;; ("\\(:#[A-Za-z0-9]+\\)" . ((lambda (tag)
          ;;                            (svg-tag-make tag :beg 2 :inverse t :margin 1 :face (doom-color 'blue) ))))
          ;; ("\\(:#[A-Za-z0-9]+:\\)$" . ((lambda (tag)
          ;;                              (svg-tag-make tag :beg 2 :end -1 :inverse t :margin 1 :face (doom-color 'blue)))))


        ;; Active date (with or without day name, with or without time)
        ;; (,(format "\\(<%s>\\)" date-re) .
        ;;  ((lambda (tag)
        ;;     (svg-tag-make tag :beg 1 :end -1 :margin 0))))
        ;; (,(format "\\(<%s \\)%s>" date-re day-time-re) .
        ;;  ((lambda (tag)
        ;;     (svg-tag-make tag :beg 1 :inverse nil :crop-right t :margin 0))))
        ;; (,(format "<%s \\(%s>\\)" date-re day-time-re) .
        ;;  ((lambda (tag)
        ;;     (svg-tag-make tag :end -1 :inverse t :crop-left t :margin 0))))

        ;; ;; Inactive date  (with or without day name, with or without time)
        ;;  (,(format "\\(\\[%s\\]\\)" date-re) .
        ;;   ((lambda (tag)
        ;;      (svg-tag-make tag :beg 1 :end -1 :margin 0 :face 'org-date))))
        ;;  (,(format "\\(\\[%s \\)%s\\]" date-re day-time-re) .
        ;;   ((lambda (tag)
        ;;      (svg-tag-make tag :beg 1 :inverse nil :crop-right t :margin 0 :face 'org-date))))
        ;;  (,(format "\\[%s \\(%s\\]\\)" date-re day-time-re) .
        ;;   ((lambda (tag)
        ;;      (svg-tag-make tag :end -1 :inverse t :crop-left t :margin 0 :face 'org-date))))

          ;; Keywords
          ("TODO" . ((lambda (tag) (svg-tag-make tag :inverse t :height .85 :face 'org-todo))))
          ("HOLD" . ((lambda (tag) (svg-tag-make tag :inverse t :height .85 :face '+org-todo-onhold))))
          ("DONE" . ((lambda (tag) (svg-tag-make tag :height .85 :face 'org-todo))))
          ("KILL" . ((lambda (tag) (svg-tag-make tag :inverse t :height .85 :face '+org-todo-cancel))))
          ("STRT\\|WAIT" . ((lambda (tag) (svg-tag-make tag :inverse t :height .85 :face '+org-todo-active))))
          ("EVNT\\|PROJ\\|IDEA" .
           ((lambda (tag) (svg-tag-make tag :inverse t :height .85 :face '+org-todo-project))))
          ("REVI" . ((lambda (tag) (svg-tag-make tag :inverse t :height .85 :face '+org-todo-onhold))))))

  :hook (org-mode . svg-tag-mode))

(setq +latex-viewers '(zathura))
(map! :map cdlatex-mode-map
      :i "TAB" #'cdlatex-tab) ;; Use TAB for cdlatex completion

(use-package! nov
  :mode ("\\.epub\\'" . nov-mode)
  :config
  (map! :map nov-mode-map
        :n "RET" #'nov-scroll-up)

  (advice-add 'nov-render-title :override #'ignore)

  (defun +nov-mode-setup ()
    "Tweak nov-mode to our liking."
    (face-remap-add-relative 'variable-pitch
                             :family "Alegreya"
                             :height 1.1
                             :width 'semi-expanded)
    (face-remap-add-relative 'default :height 1.1)
    (variable-pitch-mode 1)
    (setq-local line-spacing 0.2
                next-screen-context-lines 4
                shr-use-colors nil)
    (when (require 'visual-fill-column nil t)
      (setq-local visual-fill-column-center-text t
                  visual-fill-column-width 64
                  nov-text-width 106)
      (visual-fill-column-mode 1))
    (when (featurep 'hl-line-mode)
      (hl-line-mode -1))
    ;; Re-render with new display settings
    (nov-render-document)
    ;; Look up words with the dictionary.
    (add-to-list '+lookup-definition-functions #'+lookup/dictionary-definition))

  (add-hook 'nov-mode-hook #'+nov-mode-setup))

(defun org-nov-open-new-window (path)
  "Open nov.el link in a new window."
  (setq available-windows
        (delete (selected-window) (window-list)))
  (setq new-window
        (or (car available-windows)
            (split-window-sensibly)
            (split-window-right)))
  (select-window new-window)
  (nov-org-link-follow path))

(use-package! corfu
  :config
  (defun corfu-enable-in-minibuffer ()
    "Enable Corfu in the minibuffer if `completion-at-point' is bound."
    (when (where-is-internal #'completion-at-point (list (current-local-map)))
      ;; (setq-local corfu-auto nil) ;; Enable/disable auto completion
      (setq-local corfu-echo-delay nil ;; Disable automatic echo and popup
                  corfu-popupinfo-delay nil)
      (corfu-mode 1)))
  (add-hook 'minibuffer-setup-hook #'corfu-enable-in-minibuffer))
(use-package! orderless
  :config
  (add-to-list 'orderless-matching-styles 'char-fold-to-regexp))

(setq corfu-auto-delay 0.3)
(setq yas-triggers-in-field t)

(custom-set-faces! '((corfu-popupinfo) :height 0.9))

(defun soph/prettify-symbols-setup ()
  "Beautify keywords"
  (setq prettify-symbols-alist
        (mapcan (lambda (x) (list x (cons (upcase (car x)) (cdr x))))
                '(("#+name:" . "»")
                  ("#+title:" . "")
                  ("#+author:" . "")
                  ("#+description:" . "")
                  ("#+email" . "")
                  ("#+date" . "󰢧")
                  ("#+property" . "󰠳")
                  ("#+options" . #("󰘵" 0 1 (display (height 0.75))))
                  ("#+startup" . "⏻")
                  ("#+macro" . "ℳ")
                  ("#+bind" . "󰌷")
                  ("#+bibliography" . "")
                  ("#+print_bibliography" . "󰌱")
                  ("#+cite_export" . "⮭")
                  ("#+filetags:" . "󰓹")
                  ("#+EXPORT_FILE_NAME" . "")
                ;;("print_glossary" . "󰌱ᴬᶻ")
                ;;("glossary_sources" . "󰒻")
                  ("#+include" . "⇤")
                  ("#+setupfile" . "⇚")
                  ("#+html_head" . "🅷")
                  ("#+html" . "🅗")
                  ("#+latex_class" . "🄻")
                  ("#+latex_class_options" . "🄻󰒓")
                  ("#+latex_header" . "🅻")
                  ("#+latex_header_extra" . "🅻⁺")
                  ("#+latex" . "🅛")
                  ("#+beamer_theme" . "🄱")
                  ("#+beamer_color_theme" . "🄱󰏘")
                  ("#+beamer_font_theme" . "🄱𝐀")
                  ("#+beamer_header" . "🅱")
                  ("#+beamer" . "🅑")
                  ("#+attr_latex" . "🄛")
                  ("#+attr_html" . "🄗")
                  ("#+attr_org" . "⒪")
                  ("#+call" . "󰜎")
                  ("#+header" . "›")
                  ("#+caption" . "☰")
                  ("#+results" . "")
                  ("[ ]" . "")
                  ("[X]" . "󰄵")
                  ("[-]" . "󰡖")
                  ("#+begin_src" . "󰄾")
                  ("#+end_src" . "󰄾")
                  ("#+begin_quote" . "󰝗")
                  ("#+end_quote" . "󰉾")
                  ("#+begin_verse" . "󰴓")
                  ("#+end_verse" . "󰴓")
                  ("#+begin_example" . "")
                  ("#+end_example" . "")
                  (":PROPERTIES:" . "")
                  ("SCHEDULED:" . "󱡡")
                  ("DEADLINE:" . "󰥕")
                  ("CLOSED:" . "󰾨"))))
  (prettify-symbols-mode))

(add-hook 'org-mode-hook        #'soph/prettify-symbols-setup)
(add-hook 'org-agenda-mode-hook #'soph/prettify-symbols-setup)

;; Function to print the final value of prettify-symbols-alist for debugging
(defun print-prettify-symbols-alist ()
  "Print the prettify-symbols-alist for debugging."
  (interactive)
  (message "prettify-symbols-alist: %s" prettify-symbols-alist))

;; Add a hook to print the value after setup
(add-hook 'org-mode-hook #'print-prettify-symbols-alist)
(add-hook 'org-agenda-mode-hook #'print-prettify-symbols-alist)

(global-set-key [remap dabbrev-expand] #'hippie-expand)

(setq hippie-expand-try-functions-list
      '(try-expand-list
        try-expand-dabbrev-visible
        try-expand-dabbrev
        try-expand-all-abbrevs
        try-expand-dabbrev-all-buffers
        try-complete-file-name-partially
        try-complete-file-name
        try-expand-dabbrev-from-kill
        try-expand-whole-kill
        try-expand-line
        try-complete-lisp-symbol-partially
        try-complete-lisp-symbol))

(after! apheleia
  (setf (alist-get 'python-mode apheleia-mode-alist)
        '(ruff-isort ruff))
  (setf (alist-get 'python-ts-mode apheleia-mode-alist)
      '(ruff-isort ruff)))

(setq lsp-dart-sdk-dir "~/flutter/bin/cache/dart-sdk"
      lsp-dart-flutter-sdk "~/flutter"
      flutter-sdk-path "~/flutter")
