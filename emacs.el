;;; .emacs --- Modern Emacs 30 Configuration -*- lexical-binding: t; -*-

;;; Early Init (consider moving to early-init.el)

(setq gc-cons-threshold (* 50 1000 1000))  ; 50MB during startup
(add-hook 'emacs-startup-hook
          (lambda () (setq gc-cons-threshold (* 2 1000 1000))))  ; 2MB after

;;; UI Cleanup

(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
(when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(tooltip-mode -1)
(menu-bar-mode -1)

(global-hl-line-mode 1)
(which-function-mode 1)
(which-key-mode 1)  ; Built-in Emacs 30

(set-face-attribute 'default nil
                    :family "Source Code Pro"
                    :height 120
                    :weight 'normal
                    :width 'normal)

(set-frame-font "monaco")

(add-to-list 'default-frame-alist '(height . 24))
(add-to-list 'default-frame-alist '(width . 80))

;;; General Settings

(setq-default indent-tabs-mode nil)
(setq-default buffer-save-without-query nil)

(setq inhibit-startup-screen t
      ring-bell-function 'ignore
      use-dialog-box nil
      column-number-mode t
      xterm-query-timeout nil
      read-process-output-max (* 1024 1024))

(defalias 'yes-or-no-p 'y-or-n-p)

;;; Paths

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

;;; Keybindings

(global-set-key (kbd "C-k") 'soji/kill-line-or-region)
(global-set-key (kbd "C-c s") 'eshell)
(global-set-key (kbd "C-c c o") 'soji/find-emacs-config)
(global-set-key (kbd "<C-return>") 'save-buffer)
(global-set-key (kbd "<M-return>") 'open-line)
(global-set-key (kbd "C-y") 'soji/yank-and-indent)
(global-set-key (kbd "C-x y") 'yank)
(global-set-key (kbd "C-c =") 'soji/resize-window)
(global-set-key (kbd "M-g") 'goto-line)
(global-set-key (kbd "C-c c c") 'comment-or-uncomment-region)

;; Undo/Redo - native in Emacs 28+
(global-set-key (kbd "C-z") 'undo)
(global-set-key (kbd "C-S-z") 'undo-redo)

;; International keyboard layout workarounds
(global-set-key "æ" (kbd "M-f"))
(global-set-key "“" (kbd "M-b"))
(global-set-key "ŋ" (kbd "M-g g"))
(global-set-key "œ" (kbd "M-w"))
(global-set-key (kbd " ") " ")

;;; Mouse & Terminal

(unless window-system
  (global-set-key (kbd "<mouse-4>") 'scroll-down-line)
  (global-set-key (kbd "<mouse-5>") 'scroll-up-line))

(xterm-mouse-mode 1)
(pixel-scroll-precision-mode 1)  ; Smooth scrolling - Emacs 29+

;;; Built-in Modes

(delete-selection-mode 1)
(save-place-mode 1)
(repeat-mode 1)  ; Emacs 28+ - repeat last command easily
(show-paren-mode 1)
(setq show-paren-delay 0)

(add-hook 'text-mode-hook 'auto-fill-mode)
(add-hook 'before-save-hook 'delete-trailing-whitespace)
(add-hook 'dired-mode-hook 'dired-hide-details-mode)

;;; Backups

(setq backup-directory-alist
      `(("." . ,(concat user-emacs-directory "backups"))))

(setq auto-save-default nil
      create-lockfiles nil)

;;; Native Compilation (Emacs 29+)

(when (native-comp-available-p)
  (setq native-comp-async-report-warnings-errors 'silent
        native-comp-jit-compilation t))

;;; Package Setup

(require 'package)

(setq package-archives
      '(("gnu" . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa" . "https://melpa.org/packages/")))

(setq package-native-compile t)

(package-initialize)

(unless package-archive-contents
  (package-refresh-contents))

;; use-package is built-in Emacs 29+
(require 'use-package)
(setq use-package-always-ensure t)

;;; Tree-sitter (Emacs 29+)

(setq treesit-language-source-alist
      '((typescript "https://github.com/tree-sitter/tree-sitter-typescript" "master" "typescript/src")
        (tsx "https://github.com/tree-sitter/tree-sitter-typescript" "master" "tsx/src")
        (javascript "https://github.com/tree-sitter/tree-sitter-javascript")
        (python "https://github.com/tree-sitter/tree-sitter-python")
        (json "https://github.com/tree-sitter/tree-sitter-json")
        (css "https://github.com/tree-sitter/tree-sitter-css")
        (html "https://github.com/tree-sitter/tree-sitter-html")
        (go "https://github.com/tree-sitter/tree-sitter-go")
        (gomod "https://github.com/camdencheek/tree-sitter-go-mod")))

;; Auto-remap to tree-sitter modes
(setq major-mode-remap-alist
      '((typescript-mode . typescript-ts-mode)
        (js-mode . js-ts-mode)
        (javascript-mode . js-ts-mode)
        (python-mode . python-ts-mode)
        (json-mode . json-ts-mode)
        (css-mode . css-ts-mode)))

;; Helper to install grammars
(defun soji/treesit-install-all-grammars ()
  "Install all tree-sitter grammars."
  (interactive)
  (dolist (grammar treesit-language-source-alist)
    (unless (treesit-language-available-p (car grammar))
      (treesit-install-language-grammar (car grammar)))))

;;; Completion: Vertico + Orderless + Consult + Marginalia

(use-package vertico
  :init (vertico-mode)
  :custom
  (vertico-cycle t)
  (vertico-count 15))

(use-package vertico-directory
  :after vertico
  :ensure nil
  :bind (:map vertico-map
              ("RET" . vertico-directory-enter)
              ("DEL" . vertico-directory-delete-char)
              ("M-DEL" . vertico-directory-delete-word))
  :hook (rfn-eshadow-update-overlay . vertico-directory-tidy))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

(use-package marginalia
  :config (marginalia-mode))

(use-package consult
  :bind (("C-s" . consult-line)
         ("C-r" . consult-line)
         ("C-x b" . consult-buffer)
         ("M-y" . consult-yank-pop)
         ("M-s r" . consult-ripgrep)
         ("M-s f" . consult-find)
         ("C-c p g" . consult-ripgrep)
         ("C-c p f" . consult-find))
  :config
  (consult-customize consult-line :prompt "Search: "))

(use-package embark
  :bind (("C-." . embark-act)
         ("C-;" . embark-dwim)))

(use-package embark-consult
  :after (embark consult)
  :hook (embark-collect-mode . consult-preview-at-point-mode))

;;; Completion at Point: Corfu

(use-package corfu
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0)
  (corfu-auto-prefix 1)
  (corfu-cycle t)
  (corfu-quit-no-match 'separator)
  :config (global-corfu-mode))

(use-package corfu-terminal
  :unless (display-graphic-p)
  :after corfu
  :init (corfu-terminal-mode 1))

(use-package cape
  :after corfu
  :config
  (add-to-list 'completion-at-point-functions #'cape-file)
  (add-to-list 'completion-at-point-functions #'cape-dabbrev))

;;; Project Management (built-in)

(use-package project
  :ensure nil
  :bind (("C-c p p" . project-switch-project)
         ("C-c p f" . project-find-file)
         ("C-c p g" . project-find-regexp)
         ("C-c p k" . project-kill-buffers)
         ("C-c p s" . project-shell)))

;;; LSP: Eglot (built-in Emacs 29+)

(use-package eglot
  :ensure nil
  :hook ((typescript-ts-mode . eglot-ensure)
         (tsx-ts-mode . eglot-ensure)
         (js-ts-mode . eglot-ensure)
         (python-ts-mode . eglot-ensure)
         (go-mode . eglot-ensure)
         (go-ts-mode . eglot-ensure))
  :config
  (setq eglot-autoshutdown t
        eglot-events-buffer-size 0)
  ;; Performance optimization
  (fset #'jsonrpc--log-event #'ignore)
  ;; Server configurations (Swift uses built-in swift-mode from Emacs)
  (add-to-list 'eglot-server-programs '((swift-mode) . ("sourcekit-lsp"))))

;;; Flycheck / Flymake

;; Flymake is built-in and integrates well with eglot
(use-package flymake
  :ensure nil
  :hook (prog-mode . flymake-mode)
  :bind (:map flymake-mode-map
              ("M-n" . flymake-goto-next-error)
              ("M-p" . flymake-goto-prev-error)))

;;; Editing Packages

(use-package diminish)

(use-package xclip
  :config (xclip-mode 1))

(use-package avy
  :bind (("C-l" . avy-goto-word-1)
         ("C-c g c" . avy-goto-char-timer)))

(use-package expand-region
  :bind (("C-o" . er/expand-region)
         ("M-o" . er/expand-region)))

(use-package smartparens
  :diminish
  :hook (prog-mode . smartparens-mode)
  :config
  (require 'smartparens-config))

(use-package paredit
  :diminish
  :hook ((clojure-mode emacs-lisp-mode lisp-mode) . paredit-mode)
  :bind (:map paredit-mode-map
              ("C-k" . soji/kill-line-or-region)))

;;; Git: Magit

(use-package magit
  :bind (("C-c g s" . magit-status)
         ("C-c g f" . magit-find-file-other-window)
         ("C-c g b" . magit-blame))
  :config
  (setq vc-handled-backends nil
        magit-save-repository-buffers nil))

(use-package diff-hl
  :hook ((magit-pre-refresh . diff-hl-magit-pre-refresh)
         (magit-post-refresh . diff-hl-magit-post-refresh))
  :config (global-diff-hl-mode))

;;; Languages

(use-package typescript-ts-mode
  :ensure nil
  :mode (("\\.ts\\'" . typescript-ts-mode)
         ("\\.tsx\\'" . tsx-ts-mode)))

(use-package go-ts-mode
  :ensure nil
  :mode "\\.go\\'"
  :hook (go-ts-mode . (lambda ()
                        (setq-local tab-width 4)
                        (setq-local indent-tabs-mode t))))

(use-package python
  :ensure nil
  :mode ("\\.py\\'" . python-ts-mode))

(use-package web-mode
  :mode (("\\.html?\\'" . web-mode)
         ("\\.vue\\'" . web-mode))
  :config
  (setq web-mode-markup-indent-offset 2
        web-mode-css-indent-offset 2
        web-mode-code-indent-offset 2))

(use-package emmet-mode
  :hook ((css-mode css-ts-mode web-mode) . emmet-mode))

(use-package terraform-mode
  :mode "\\.tf\\'")

;;; Org Mode

(use-package org
  :ensure nil
  :hook ((org-mode . auto-revert-mode)
         (org-mode . org-indent-mode))
  :config
  (require 'org-tempo)
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t)
     (shell . t)
     (python . t))))

(use-package org-download)

;;; Snippets

(use-package yasnippet
  :diminish yas-minor-mode
  :hook (prog-mode . yas-minor-mode)
  :config (yas-reload-all))

(use-package yasnippet-snippets
  :after yasnippet
  :config (yas-reload-all))

;;; Misc Packages

(use-package restclient)

(use-package docker
  :bind ("C-c d" . docker))

(use-package exec-path-from-shell
  :if (memq window-system '(mac ns x))
  :config (exec-path-from-shell-initialize))

(use-package ripgrep)

;;; Dired

(use-package dired
  :ensure nil
  :bind (:map dired-mode-map
              ("N" . make-directory))
  :config
  (setq dired-dwim-target t
        dired-kill-when-opening-new-dired-buffer t)  ; Emacs 28+
  (put 'dired-find-alternate-file 'disabled nil))

;;; Custom Key Chords (if you still want them)

(use-package use-package-chords
  :config (key-chord-mode 1))

(use-package rgtk
  :ensure nil
  :no-require t
  :chords (("/r" . revert-buffer)
           (";c" . soji/find-corresponding-file)
           (";w" . save-buffer)
           (";q" . kill-this-buffer)
           (";a" . other-window)
           (";b" . consult-buffer)
           (";1" . delete-other-windows)
           (";2" . split-window-below)
           (";3" . split-window-right)
           (";d" . find-file)
           (";4" . consult-goto-line)
           (";z" . pop-global-mark)
           (";f" . project-find-file)
           (";g" . consult-ripgrep)
           (";s" . consult-line)
           (";v" . consult-imenu))
  :config
  (key-chord-define minibuffer-local-map ";g" 'keyboard-quit))

;;; Custom Functions

(defun soji/save-and-kill-buffer ()
  "Save and kill current buffer."
  (interactive)
  (save-buffer)
  (kill-this-buffer))

(defun soji/window-split-toggle ()
  "Toggle between horizontal and vertical split with two windows."
  (interactive)
  (if (> (length (window-list)) 2)
      (error "Can't toggle with more than 2 windows!")
    (let ((func (if (window-full-height-p)
                    #'split-window-vertically
                  #'split-window-horizontally)))
      (delete-other-windows)
      (funcall func)
      (save-selected-window
        (other-window 1)
        (switch-to-buffer (other-buffer))))))

(defun soji/resize-window (&optional arg)
  "Resize window interactively."
  (interactive "p")
  (if (one-window-p)
      (error "Cannot resize sole window"))
  (or arg (setq arg 9))
  (let (c)
    (catch 'done
      (while t
        (message "[n]arrow [w]iden [h]eighten [s]hrink [1-9] unit [q]uit")
        (setq c (read-char))
        (condition-case ()
            (cond
             ((= c ?h) (enlarge-window arg))
             ((= c ?s) (shrink-window arg))
             ((= c ?w) (enlarge-window-horizontally arg))
             ((= c ?n) (shrink-window-horizontally arg))
             ((= c ?\^G) (keyboard-quit))
             ((= c ?q) (throw 'done t))
             ((and (> c ?0) (<= c ?9)) (setq arg (- c ?0)))
             (t (beep)))
          (error (beep)))))
    (message "Done.")))

(defun soji/save-cursor-location ()
  "Save FILENAME:LINE to kill-ring."
  (interactive)
  (if-let ((path (buffer-file-name)))
      (progn
        (kill-new (format "%s:%d" path (line-number-at-pos)))
        (message "Location saved to kill-ring."))
    (message "Buffer doesn't have file open.")))

(defun soji/clip-file-name-nondirectory ()
  "Copy file name without directory to kill-ring."
  (interactive)
  (when buffer-file-name
    (kill-new (file-name-nondirectory buffer-file-name))))

(defun soji/clip-file-name ()
  "Copy full file path to kill-ring."
  (interactive)
  (when buffer-file-name
    (kill-new buffer-file-name)))

(defun soji/kill-line-or-region ()
  "Kill region if active, otherwise kill line."
  (interactive)
  (if (region-active-p)
      (delete-region (region-beginning) (region-end))
    (if (bound-and-true-p paredit-mode)
        (paredit-kill)
      (kill-line))))

(defun soji/yank-and-indent ()
  "Yank and indent the newly formed region."
  (interactive)
  (yank)
  (indent-region (region-beginning) (region-end)))

(defun soji/find-emacs-config ()
  "Open Emacs init file."
  (interactive)
  (find-file (expand-file-name "init.el" user-emacs-directory)))

(defun soji/find-corresponding-file ()
  "Find corresponding file (e.g., .tsx <-> .less)."
  (interactive)
  (when-let* ((base (file-name-base (buffer-file-name)))
              (extension (file-name-extension (buffer-file-name)))
              (match (seq-find
                      (lambda (ext)
                        (and (not (string= ext extension))
                             (file-readable-p (concat base "." ext))))
                      '("less" "tsx" "ts" "js" "css" "scss"))))
    (find-file (concat base "." match))))

;;; End
(provide 'init)
;;; .emacs ends here
