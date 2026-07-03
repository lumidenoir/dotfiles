;;; ~/.config/doom/config.el -*- lexical-binding: t; -*-
(setq user-full-name "Lumi Denoir"
      user-mail-address "lumidenoir@gmail.com")

(defvar lumi-ui-presets
  '(("JBM" . (:font "JetBrains Mono" :size 15 :weight regular :slant normal
              :big-font "JetBrains Mono" :big-size 25
              :vp-font "Inter 28pt" :vp-size 16
              :emoji-font "Noto Color Emoji"
              :symbol-font "JuliaMono Nerd Font"
              :serif-font "JetBrains Mono" :serif-size 15 :serif-weight light
              :theme doom-one
              :org-heading-font "Inter 28pt" :org-heading-weight bold))
    ("Metric Perfect" . (:font "Iosevka" :size 15 :weight regular :slant normal :width expanded :spacing 90
              :big-font "Iosevka" :big-size 25
              :vp-font "Iosevka Aile" :vp-size 15
              :emoji-font "Noto Color Emoji"
              :symbol-font "Iosevka"
              :serif-font "IosevkaTermSlab Nerd Font" :serif-size 15 :serif-weight light
              :theme doom-one
              :org-heading-font "Iosevka Aile" :org-heading-weight bold))
    ("Studio Tech" . (:font "Lilex Nerd Font Mono" :size 15 :weight medium :slant normal
              :big-font "Lilex Nerd Font" :big-size 25
              :vp-font "IBM Plex Sans" :vp-size 15
              :emoji-font "Noto Color Emoji"
              :symbol-font "Iosevka"
              :serif-font "IosevkaTermSlab Nerd Font" :serif-size 15 :serif-weight light
              :theme doom-one
              :org-heading-font "IBM Plex Sans" :org-heading-weight bold))
    ("Recursive" . (:font "Recursive Monospace" :size 15 :weight regular :slant normal
              :big-font "Recursive Monospace" :big-size 25
              :vp-font "Recursive" :vp-size 15
              :emoji-font "Noto Color Emoji"
              :symbol-font "Iosevka"
              :serif-font "Space Grotesk" :serif-size 15 :serif-weight light
              :theme doom-one
              :org-heading-font "Space Grotesk" :org-heading-weight bold))
    ("Neutral Architect" . (:font "CommitMono" :size 15 :weight regular :slant normal
              :big-font "CommitMono" :big-size 25
              :vp-font "Inter 28pt" :vp-size 16
              :emoji-font "Noto Color Emoji"
              :symbol-font "Iosevka"
              :serif-font "Inter 28pt" :serif-size 15 :serif-weight light
              :theme doom-one
              :org-heading-font "Inter 28pt" :org-heading-weight bold))
    ("Rounded Modernist" . (:font "Maple Mono" :size 15 :weight regular :slant normal
              :big-font "Maple Mono" :big-size 25
              :vp-font "Satoshi" :vp-size 16
              :emoji-font "Noto Color Emoji"
              :symbol-font "Iosevka"
              :serif-font "IosevkaTermSlab Nerd Font" :serif-size 15 :serif-weight light
              :theme doom-one
              :org-heading-font "Satoshi" :org-heading-weight semibold
              :org-title-font "Bricolage Grotesque" :org-title-weight semibold))
    ("Quiet minimalist" . (:font "CommitMono" :size 15 :weight regular :slant normal
              :big-font "Commit Mono" :big-size 25
              :vp-font "Recursive" :vp-size 16
              :emoji-font "Noto Color Emoji"
              :symbol-font "Iosevka"
              :serif-font "IBM Plex Serif" :serif-size 15 :serif-weight light
              :theme doom-one
              :org-heading-font "IBM Plex Serif" :org-heading-weight semibold
              :org-title-font "IBM Plex Serif" :org-title-weight bold))
    ("Monaspace" . (:font "Monaspace Radon" :size 15 :weight regular :slant normal
              :big-font "Monaspace Radon" :big-size 25
              :vp-font "Iosevka Charon" :vp-size 16
              :emoji-font "Noto Color Emoji"
              :symbol-font "Iosevka"
              :serif-font "Monaspace Xenon" :serif-size 15 :serif-weight light
              :theme doom-one
              :org-heading-font "Iosevka Charon" :org-heading-weight semibold
              :org-title-font "Iosevka Charon" :org-title-weight bold))
    ("Sharp Functionalist" . (:font "Ioskeley Mono" :size 15 :weight regular :slant normal
              :big-font "Ioskeley Mono" :big-size 25
              :vp-font "Iosevka Charon" :vp-size 16
              :emoji-font "Noto Color Emoji"
              :symbol-font "Iosevka"
              :serif-font "GeistMono Nerd Font" :serif-size 15 :serif-weight light
              :theme doom-one
              :org-heading-font "Geist" :org-heading-weight semibold
              :org-title-font "Geist" :org-title-weight bold))
    ("Highway" . (:font "FiraCode Nerd Font" :size 15 :weight regular :slant normal
              :big-font "FiraCode Nerd Font" :big-size 25
              :vp-font "Overpass Nerd Font" :vp-size 16
              :emoji-font "Noto Color Emoji"
              :symbol-font "JuliaMono Nerd Font"
              :serif-font "IBM Plex Mono" :serif-size 15 :serif-weight light
              :theme doom-one
              :org-heading-font "Overpass Nerd Font" :org-heading-weight bold))
    ("Neo-Cyberpunk" . (:font "0xProto Nerd Font Mono" :size 15 :weight regular :slant normal
              :big-font "0xProto Nerd Font Mono" :big-size 25
              :vp-font "Satoshi" :vp-size 15
              :emoji-font "Noto Color Emoji"
              :symbol-font "Iosevka"
              :serif-font "IBM Plex Serif" :serif-size 15 :serif-weight light
              :theme doom-one
              :org-heading-font "Satoshi" :org-heading-weight bold))
    ("Vercel Minimalist" . (:font "GeistMono Nerd Font Mono" :size 15 :weight regular :slant normal
              :big-font "GeistMono Nerd Font Mono" :big-size 25
              :vp-font "Geist" :vp-size 15
              :emoji-font "Noto Color Emoji"
              :symbol-font "Iosevka"
              :serif-font "GeistMono Nerd Font" :serif-size 15 :serif-weight light
              :theme doom-one
              :org-heading-font "Geist" :org-heading-weight bold))
    ("Cursive Elegance" . (:font "VictorMono Nerd Font Mono" :size 15 :weight regular :slant normal
              :big-font "VictorMono Nerd Font Mono" :big-size 25
              :vp-font "Inter" :vp-size 15
              :emoji-font "Noto Color Emoji"
              :symbol-font "Iosevka"
              :serif-font "IBM Plex Serif" :serif-size 15 :serif-weight light
              :theme doom-one
              :org-heading-font "Inter" :org-heading-weight bold))
    ("Cozy Cascadia" . (:font "CaskaydiaCove Nerd Font Mono" :size 15 :weight regular :slant normal
              :big-font "CaskaydiaCove Nerd Font Mono" :big-size 25
              :vp-font "Bricolage Grotesque" :vp-size 15
              :emoji-font "Noto Color Emoji"
              :symbol-font "Iosevka"
              :serif-font "IBM Plex Serif" :serif-size 15 :serif-weight light
              :theme doom-one
              :org-heading-font "Bricolage Grotesque" :org-heading-weight bold))
    ("Playful Geometry" . (:font "FantasqueSansM Nerd Font Mono" :size 15 :weight regular :slant normal
              :big-font "FantasqueSansM Nerd Font Mono" :big-size 25
              :vp-font "Satoshi" :vp-size 15
              :emoji-font "Noto Color Emoji"
              :symbol-font "Iosevka"
              :serif-font "IBM Plex Serif" :serif-size 15 :serif-weight light
              :theme doom-one
              :org-heading-font "Satoshi" :org-heading-weight bold))
    ("Comic Hacking" . (:font "ComicShannsMono Nerd Font Mono" :size 16 :weight regular :slant normal
              :big-font "ComicShannsMono Nerd Font Mono" :big-size 25
              :vp-font "Bricolage Grotesque" :vp-size 15
              :emoji-font "Noto Color Emoji"
              :symbol-font "Iosevka"
              :serif-font "IBM Plex Serif" :serif-size 15 :serif-weight light
              :theme doom-one
              :org-heading-font "Bricolage Grotesque" :org-heading-weight bold))
    )
  "Alist of UI preset properties.")

(defun lumi/apply-ui-preset (preset-name)
  "Apply the UI preset defined in `lumi-ui-presets`."
  (let* ((props (cdr (assoc preset-name lumi-ui-presets)))
         (font-alist `(:family ,(plist-get props :font) :size ,(plist-get props :size)
                       :weight ,(plist-get props :weight) :slant ,(plist-get props :slant)))
         ;; Add width and spacing if available
         (font-alist (if (plist-get props :width) (plist-put font-alist :width (plist-get props :width)) font-alist))
         (font-alist (if (plist-get props :spacing) (plist-put font-alist :spacing (plist-get props :spacing)) font-alist)))

    (setq doom-font (apply #'font-spec font-alist)
          doom-big-font-mode (font-spec :family (plist-get props :big-font) :size (plist-get props :big-size))
          doom-variable-pitch-font (font-spec :family (plist-get props :vp-font) :size (plist-get props :vp-size))
          doom-emoji-font (font-spec :family (plist-get props :emoji-font))
          doom-symbol-font (font-spec :family (plist-get props :symbol-font))
          doom-serif-font (font-spec :family (plist-get props :serif-font) :size (plist-get props :serif-size) :weight (plist-get props :serif-weight))
          doom-theme (plist-get props :theme)
          display-line-numbers-type nil)

    (doom/reload-font)

    (let* ((heading-font (plist-get props :org-heading-font))
           (heading-weight (plist-get props :org-heading-weight))
           (title-font (or (plist-get props :org-title-font) (plist-get props :org-heading-font)))
           (title-weight (or (plist-get props :org-title-weight) (plist-get props :org-heading-weight)))
           (apply-fn
            (lambda ()
              (dolist (face '((org-level-1 . 1.4) (org-level-2 . 1.3) (org-level-3 . 1.2)
                              (org-level-4 . 1.1) (org-level-5 . 1.1) (org-level-6 . 1.1)
                              (org-level-7 . 1.1) (org-level-8 . 1.1)))
                (set-face-attribute (car face) nil :font heading-font :weight heading-weight :height (cdr face)))
              (set-face-attribute 'org-document-title nil :font title-font :weight title-weight :height 1.8))))
      (if (featurep 'org)
          (funcall apply-fn)
        (eval-after-load 'org `(funcall ,apply-fn))))
    (message "Applied UI Preset: %s" preset-name)))

(defun lumi/load-ui-preset ()
  "Interactively pick and load a UI preset, displaying active fonts in brackets."
  (interactive)
  (let* ((choices (mapcar (lambda (preset)
                            (let* ((name (car preset))
                                   (props (cdr preset))
                                   (font (plist-get props :font))
                                   (vp-font (plist-get props :vp-font)))
                              (cons (format "%s [%s | %s]" name font vp-font) name)))
                          lumi-ui-presets))
         (selection (completing-read "Select UI Preset: " (mapcar #'car choices)))
         (preset-name (cdr (assoc selection choices))))
    (when preset-name
      (lumi/apply-ui-preset preset-name))))

;; Set default on startup
(lumi/apply-ui-preset "JBM")

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

;; Enable org-fragtog-mode for automatic LaTeX fragment toggling
(add-hook 'org-mode-hook 'org-fragtog-mode)
(setq org-startup-with-latex-preview t) ;; Start with LaTeX preview enabled
(setq org-preview-latex-default-process 'dvisvgm)
(after! org
  (setq org-format-latex-options
        (plist-put org-format-latex-options :scale 0.85)))
(setq org-cite-csl-styles-dir "/home/lumi/Zotero/styles") ;; Path to CSL styles for citations
(setq reftex-default-bibliography "/home/lumi/org/zotero.bib"
      org-agenda-files '("/home/lumi/org/todo.org" "/home/lumi/org/todoist.org")
      org-fold-catch-invisible-edits 'smart)
(setq org-export-headline-levels 5) ; I like nesting
(setq org-ellipsis " ▾ ")

(after! org
  (setq org-adapt-indentation t)
  ;; Set some faces for various org elements
  (custom-set-faces!
    ;; Customize org-quote
    `((org-quote) :foreground ,(doom-color 'blue) :extend t :italic t)
    ;; Customize org-verse
    `((org-verse) :foreground ,(doom-color 'yellow)  :extend t :italic t))
  ;; Change how LaTeX and image previews are shown
  (setq org-highlight-latex-and-related '(native entities script)))

;; Use Doom's native popup engine to push Org Edit buffers to the right
(setq org-src-window-setup 'other-window)
(set-popup-rule! "^\\*Org Src" :side 'right :size 0.5 :quit nil :select t :modeline t)

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
    `((org-modern-radio-target org-modern-internal-target)
      :inherit 'default :foreground ,(doom-color 'blue))))

(use-package! org-appear
  :hook (org-mode . org-appear-mode)
  :config
  (setq org-appear-autoemphasis t
        org-appear-autosubmarkers t
        org-appear-autolinks nil))

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

(defvar lumi-prettify-org-symbols-alist
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

(defun soph/prettify-symbols-setup ()
  "Beautify keywords using pre-computed mapping."
  (setq prettify-symbols-alist lumi-prettify-org-symbols-alist)
  (prettify-symbols-mode))

(add-hook 'org-mode-hook        #'soph/prettify-symbols-setup)
(add-hook 'org-agenda-mode-hook #'soph/prettify-symbols-setup)

(after! org
  (setq org-src-preserve-indentation t)
  (setq org-src-fontify-natively t
        org-src-tab-acts-natively t
        org-edit-src-content-indentation 0))

(defun date-three-days-later ()
  "Return the date three days from today in the format YYYY-MM-DD."
  (let* ((today (current-time))
         (three-days-later (time-add today (* 3 24 60 60)))
         (date-string (format-time-string "%Y-%m-%d" three-days-later)))
    date-string))

(defadvice! lumi/update-agenda-dates-a (&rest _)
  :before #'org-agenda
  (let ((date-three-days-later (date-three-days-later)))
    (setq org-agenda-custom-commands
          `(("c" "Super view"
             ((alltodo "" ((org-agenda-overriding-header "")
                           (org-super-agenda-groups
                            '((:name "Actionable Today" :deadline today :scheduled today :face (:foreground "green") :order 1)
                              (:name "Overdue" :deadline past :face (:foreground "red") :order 2)
                              (:name "Deadline soon" :face (:foreground "orange") :deadline (before ,date-three-days-later) :order 3)
                              (:habit t)
                              (:name "Scheduled for Future" :scheduled future :face (:foreground "blue") :order 4)
                              (:name "In Progress" :todo ("STRT" "WAIT" "HOLD") :and (:scheduled past :deadline future) :order 5)
                              (:name "Not yet started" :todo ("TODO" "PROJ" "IDEA") :scheduled nil :deadline nil :order 6)))))))))))

(use-package! org-super-agenda
  :after org-agenda
  :config
  (org-super-agenda-mode))

;; Set the directory for Org-roam files
(setq org-roam-directory (file-truename "~/org/"))

;; Define capture templates for Org-roam
(setq org-roam-capture-templates
    '(("d" "default" plain "%?" :target
       (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "#+TITLE:${title}\n#+filetags: :incomplete:\n#+DATE: %U\n#+EXPORT_FILE_NAME: ${slug}\n")
       :unnarrowed t)
("p" "problem" plain "%?"
         :if-new (file+head "problems/${slug}.org"
                            "#+title: ${title}\n#+filetags: :cp:cf: \n\n* Notes\n\n* Solution\n#+begin_src cpp :tangle /tmp/cp/${slug}.cpp\n#include <bits/stdc++.h>\nusing namespace std;\n\ntypedef long long ll;\n\nint main() {\n  ios_base::sync_with_stdio(false);\n  cin.tie(nullptr);\n  \n  return 0;\n}\n#+end_src\n\n")
         :unnarrowed t)
      ))

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
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start t))

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
                      (user-full-name               . "Lumi Dantu")
                      (smtpmail-smtp-user           . "viveksk21@iitk.ac.in")
                      (smtpmail-default-smtp-server . "mmtp.iitk.ac.in")
                      (smtpmail-smtp-server         . "smtp.cc.iitk.ac.in")
                      (smtpmail-smtp-service        .  465)
                      (mu4e-compose-signature       . "Krishna Dantu,\n210299"))
                    t)

;; Prompt for context if not specified
(setq mu4e-context-policy 'ask-if-none
      mu4e-update-interval 300
      mu4e-compose-context-policy 'always-ask
      mu4e-index-cleanup nil
      mu4e-index-lazy-check t)

(use-package! corfu
  :config
  (defun corfu-enable-in-minibuffer ()
    "Enable Corfu in the minibuffer if `completion-at-point' is bound."
    (when (where-is-internal #'completion-at-point (list (current-local-map)))
      (setq-local corfu-echo-delay nil
                  corfu-popupinfo-delay nil)
      (corfu-mode 1)))
  (add-hook 'minibuffer-setup-hook #'corfu-enable-in-minibuffer))

(use-package! orderless
  :config
  (add-to-list 'orderless-matching-styles 'char-fold-to-regexp))

(setq corfu-auto-delay 0.3)
(setq yas-triggers-in-field t)

(custom-set-faces! '((corfu-popupinfo) :height 0.9))

;; Hippie Expand
;; An advanced autocomplete module in Emacs that tries to guess the completion of a word based on an evolving list of rules.
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

;; Ruff Format (Python)
(with-eval-after-load 'python
  (set-formatter! 'ruff :modes '(python-mode python-ts-mode)))

;; Flutter & Dart Development
(setq lsp-dart-sdk-dir "~/flutter/bin/cache/dart-sdk"
      lsp-dart-flutter-sdk "~/flutter"
      flutter-sdk-path "~/flutter")

;; Latex mode
(setq +latex-viewers '(zathura))
(map! :map cdlatex-mode-map
      :i "TAB" #'cdlatex-tab) ;; Use TAB for cdlatex completion

(defun lumi/cf-sync-tags-in-buffer ()
  "Update #+filetags in the current buffer using cf_tags.py."
  (interactive)
  (let* ((filename (buffer-file-name))
         (problem-id (file-name-nondirectory filename))
         (tags (string-trim
                (shell-command-to-string
                 (format "echo %s | cf_tags.py"
                         (shell-quote-argument problem-id))))))
    (when (and tags (not (string-empty-p tags)) (string-prefix-p ":" tags) (string-suffix-p ":" tags))
      (save-excursion
        (goto-char (point-min))
        (if (re-search-forward "^#\\+filetags:.*" nil t)
            (replace-match (concat "#+filetags: " tags))
          (goto-char (point-min))
          (if (re-search-forward "^#\\+title:.*" nil t)
              (progn (forward-line 1)
                     (insert "#+filetags: " tags "\n"))
            (insert "#+filetags: " tags "\n"))))
      (save-buffer)
      (message "CF tags updated: %s" tags))))

(defun lumi/run-cf-sync-after-capture ()
  "Run CodeForces sync when finishing a cf_ problem capture."
  (unless org-note-abort
    (when-let* ((marker org-capture-last-stored-marker)
                (file   (buffer-file-name (marker-buffer marker))))
      (when (string-match-p "cf_" (file-name-nondirectory file))
        (let ((buf (or (get-file-buffer file)
                       (find-file-noselect file))))
          (with-current-buffer buf
            (lumi/cf-sync-tags-in-buffer))
          (unless (get-file-buffer file)
            (kill-buffer buf)))))))

(add-hook 'org-capture-after-finalize-hook #'lumi/run-cf-sync-after-capture)

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
