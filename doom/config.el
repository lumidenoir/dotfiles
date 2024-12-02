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
(setq org-cite-csl-styles-dir "/home/krishna/Zotero/styles") ;; Path to CSL styles for citations

(setq reftex-default-bibliography "/home/krishna/org/zotero.bib"
      org-agenda-files '("/home/krishna/org/todo.org" "/home/krishna/org/calendar.org" "/home/krishna/org/todoist.org"))
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

(after! (org-roam kind-icon)
  (add-to-list
   'kind-icon-mapping
   `(org-roam ,(nerd-icons-codicon "nf-cod-symbol_interface") :face font-lock-type-face)))

(after! (org-roam nerd-icons-corfu)
  (add-to-list
   'nerd-icons-corfu-mapping
   '(org-roam :style "cod" :icon "symbol_interface" :face font-lock-type-face)))


(after! org-roam
  ;; Define advise
  (defun hp/org-roam-capf-add-kind-property (orig-fun &rest args)
    "Advice around `org-roam-complete-link-at-point' to add :company-kind property."
    (let ((result (apply orig-fun args)))
      (append result '(:company-kind (lambda (_) 'org-roam)))))
  ;; Wraps around the relevant functions
  (advice-add 'org-roam-complete-link-at-point :around #'hp/org-roam-capf-add-kind-property)
  (advice-add 'org-roam-complete-everywhere :around #'hp/org-roam-capf-add-kind-property))

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

(use-package! citar
  :after oc
  :custom
  (org-cite-insert-processor 'citar)
  (org-cite-follow-processor 'citar)
  (org-cite-activate-processor 'citar)
  (citar-bibliography '("~/org/zotero.bib"))
  (citar-org-roam-note-title-template "${author} - ${title}\n"))

;; Additional paths for Citar
(setq! citar-bibliography '("/home/krishna/org/zotero.bib"))
(setq! citar-library-paths '("~/org/assets/books/")
       citar-notes-paths '("~/org/"))

(use-package! citar-org-roam
  :after (citar org-roam)
  :config (citar-org-roam-mode))

(after! citar
  ;; Define advise
  (defun hp/citar-capf-add-kind-property (orig-fun &rest args)
    "Advice around `org-roam-complete-link-at-point' to add :company-kind property."
    (let ((result (apply orig-fun args)))
      (append result '(:company-kind (lambda (_) 'reference)))))
  ;; Wraps around the relevant functions
  (advice-add 'citar-capf :around #'hp/citar-capf-add-kind-property))
(after! (org-roam kind-icon)
  (add-to-list
   'kind-icon-mapping
   `(org-roam ,(nerd-icons-codicon "nf-cod-symbol_interface") :face font-lock-type-face)))

(setq org-noter-always-create-frame nil
      org-noter-kill-frame-at-session-end nil)

(use-package! org-habit
  :custom
  (org-habit-graph-column 1)
  (org-habit-preceding-days 7)
  (org-habit-following-days 3)
  (org-habit-show-habits-only-for-today nil))

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

(setq +zen-text-scale 0.8)
(defvar +zen-serif-p t
  "Whether to use a serifed font with `mixed-pitch-mode'.")
(defvar +zen-org-starhide t
  "The value `org-modern-hide-stars' is set to.")

(after! writeroom-mode
  (defvar-local +zen--original-org-indent-mode-p nil)
  (defvar-local +zen--original-mixed-pitch-mode-p nil)
  (defun +zen-enable-mixed-pitch-mode-h ()
    "Enable `mixed-pitch-mode' when in `+zen-mixed-pitch-modes'."
    (when (apply #'derived-mode-p +zen-mixed-pitch-modes)
      (if writeroom-mode
          (progn
            (setq +zen--original-mixed-pitch-mode-p mixed-pitch-mode)
            (funcall (if +zen-serif-p #'mixed-pitch-serif-mode #'mixed-pitch-mode) 1))
        (funcall #'mixed-pitch-mode (if +zen--original-mixed-pitch-mode-p 1 -1)))))
  (defun +zen-prose-org-h ()
    "Reformat the current Org buffer appearance for prose."
    (when (eq major-mode 'org-mode)
      (setq display-line-numbers nil
            visual-fill-column-width 80
            org-adapt-indentation nil)
      (when (featurep 'org-modern)
        (setq-local org-modern-star '("⚜" "⚜" "⚜" "⚜")
                    org-modern-hide-stars +zen-org-starhide)
        (org-modern-mode -1)
        (org-modern-mode 1))
      (setq
       +zen--original-org-indent-mode-p org-indent-mode)
      (org-indent-mode -1)))
  (defun +zen-nonprose-org-h ()
    "Reverse the effect of `+zen-prose-org'."
    (when (eq major-mode 'org-mode)
      (when (bound-and-true-p org-modern-mode)
        (org-modern-mode -1)
        (org-modern-mode 1))
      (when +zen--original-org-indent-mode-p (org-indent-mode 1))))
  (pushnew! writeroom--local-variables
            'display-line-numbers
            'visual-fill-column-width
            'org-adapt-indentation
            'org-modern-mode
            'org-modern-star
            'org-modern-hide-stars)
  (add-hook 'writeroom-mode-enable-hook #'+zen-prose-org-h)
  (add-hook 'writeroom-mode-disable-hook #'+zen-nonprose-org-h))

;; Add mu4e to the load path
(add-to-list 'load-path "/usr/share/emacs/site-lisp/mu4e/")

;; Toggle org-msg in mu4e
(setq +mu4e-compose-org-msg-toggle-next nil)

;; Setting msmtp for sending emails
(after! mu4e
  (setq sendmail-program (executable-find "msmtp")
        send-mail-function #'smtpmail-send-it
        message-sendmail-f-is-evil t
        message-sendmail-extra-arguments '("--read-envelope-from")
        message-send-mail-function #'message-send-mail-with-sendmail))

;; Configure mu4e contexts for different email accounts
(set-email-account! "iitk"
                    '((mu4e-sent-folder             . "/iitk/Sent")
                      (mu4e-drafts-folder           . "/iitk/Drafts")
                      (mu4e-trash-folder            . "/iitk/Trash")
                      (mu4e-refile-folder           . "/iitk/All Mail")
                      (user-mail-address            . "viveksk21@iitk.ac.in")
                      (user-full-name               . "Krishna Dantu")
                      (smtpmail-smtp-user           . "viveksk21@iitk.ac.in")
                      (smtpmail-default-smtp-server . "mmtp.iitk.ac.in")
                      (smtpmail-smtp-server         . "smtp.cc.iitk.ac.in")
                      (smtpmail-smtp-service        .  465)
                      (mu4e-compose-signature       . "Krishna Dantu,\n210299"))
                    t)

(set-email-account! "gmail"
                    '((mu4e-sent-folder       . "/gmail/[Gmail]/Sent Mail")
                      (mu4e-drafts-folder     . "/gmail/[Gmail]/Drafts")
                      (mu4e-trash-folder      . "/gmail/[Gmail]/Bin")
                      (mu4e-refile-folder     . "/gmail/[Gmail]/All Mail")
                      (user-mail-address      . "lumidenoir@gmail.com")
                      (user-full-name         . "lumi denoir")
                      (smtpmail-smtp-user     . "lumidenoir@gmail.com")
                      (smtpmail-smtp-server   . "smtp.gmail.com")
                      (smtpmail-smtp-service  .  465)
                      (mu4e-compose-signature . "Yours truly,\nLumi Denoir"))
                    t)

;; Prompt for context if not specified
(setq mu4e-context-policy 'ask-if-none
      mu4e-update-interval 300
      mu4e-compose-context-policy 'always-ask
      mu4e-index-cleanup nil
      mu4e-index-lazy-check t)

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

(defun ipynb-to-markdown (file)
  (interactive "f")
  (let* ((data (with-temp-buffer
                 (insert-file-contents file)
                 (json-parse-buffer :object-type 'alist
                                    :array-type 'list)))
         (metadata (alist-get 'metadata data))
         (language-info (alist-get 'language_info metadata))
         (language (alist-get 'name language-info)))
    (pop-to-buffer "ipynb-as-markdown")
    (when (featurep 'markdown-mode)
      (markdown-mode))
    (dolist (cell (alist-get 'cells data))
      (let ((cell-type (alist-get 'cell_type cell))
            (source (alist-get 'source cell))
            (outputs (alist-get 'outputs cell)))
        (pcase cell-type
          ("markdown"
           (when source
             (mapc #'insert source)
             (insert "\n\n")))
          ("code"
           (when source
             (insert (format "```%s\n" language))
             (mapc #'insert source)
             (insert "\n```\n\n")
             (dolist (output outputs)
               (let ((output-text (alist-get 'text output))
                     (output-data (alist-get 'data output)))
                 (when output-text
                   (insert "```stdout\n")
                   (insert (mapconcat #'identity output-text ""))
                   (insert "\n```\n\n"))
                 (when output-data
                   (when-let ((image64 (alist-get 'image/png output-data)))
                     (let ((image-data (base64-decode-string image64)))
                       (insert-image (create-image image-data 'png t))
                       (insert "\n\n")))))))))))))

(defun ldn/update-project-changelog ()
  "Update ChangeLog.org with latest git commits under Changelog heading."
  (interactive)
  (let ((readme-file (expand-file-name "ChangeLog.org" (projectile-project-root)))
        (commit-log (shell-command-to-string (expand-file-name "extract_commits.sh" (projectile-project-root)))))
    (if (string-match-p "No new commits to add." commit-log)
        (message "No new commits to add.")
      (with-current-buffer (find-file-noselect readme-file)
        (goto-char (point-min))
        ;; Find the Changelog heading
        (if (re-search-forward "^\\*+ Changelog" nil t)
            (progn
              (forward-line)
              (insert commit-log "\n"))
          (goto-char (point-max))
          (insert "\n* Changelog\n" commit-log "\n"))
        (save-buffer)
        (message "Changelog updated in README.org!")))))

(map! :leader
      :desc "Update ChangeLog.org"
      "p u" #'ldn/update-project-changelog)

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

(setq lsp-dart-sdk-dir "~/flutter/bin/cache/dart-sdk"
      lsp-dart-flutter-sdk "~/flutter"
      flutter-sdk-path "~/flutter")
