;;; lsp-metals.el --- Scala Client settings             -*- lexical-binding: t; -*-

;; Copyright (C) 2018-2019 Ross A. Baker <ross@rossabaker.com>, Evgeny Kurnevsky <kurnevsky@gmail.com>

;; Version: 1.0.0
;; Package-Requires: ((emacs "26.1") (scala-mode "1.1") (lsp-mode "7.0") (lsp-treemacs "0.2") (dap-mode "0.3") (dash "2.18.0") (f "0.20.0") (ht "2.0") (treemacs "2.5"))
;; Author: Ross A. Baker <ross@rossabaker.com>
;;         Evgeny Kurnevsky <kurnevsky@gmail.com>
;; Keywords: languages, extensions
;; URL: https://github.com/emacs-lsp/lsp-metals

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; lsp-metals client

;;; Code:

(require 'lsp-mode)
(require 'dap-mode)
(require 'lsp-lens)
(require 'lsp-metals-protocol)
(require 'lsp-metals-treeview)
(require 'view)

(defgroup lsp-metals nil
  "LSP support for Scala, using Metals."
  :group 'lsp-mode
  :link '(url-link "https://scalameta.org/metals")
  :package-version '(lsp-metals . "1.0"))

(defcustom lsp-metals-server-command "metals"
  "The command to launch the Scala language server."
  :group 'lsp-metals
  :type 'file
  :package-version '(lsp-metals . "1.0"))

(defcustom lsp-metals-server-args '()
  "Extra arguments for the Scala language server."
  :group 'lsp-metals
  :type '(repeat string)
  :package-version '(lsp-metals . "1.0"))

(defcustom lsp-metals-server-install-dir
  (f-join lsp-server-install-dir "metals/")
  "Installation directory for Metals server."
  :group 'lsp-metals
  :type 'directory
  :package-version '(lsp-metals . "1.2"))

(defcustom lsp-metals-coursier-store-path
  (f-join lsp-metals-server-install-dir "coursier")
  "The path where Coursier will be stored."
  :group 'lsp-metals
  :type 'file
  :package-version '(lsp-metals . "1.2"))

(defcustom lsp-metals-metals-store-path
  (f-join lsp-metals-server-install-dir "metals")
  "The path where Metals will be stored."
  :group 'lsp-metals
  :type 'file
  :package-version '(lsp-metals . "1.2"))

(defcustom lsp-metals-coursier-download-url
  (pcase system-type
    (`windows-nt "https://github.com/coursier/launchers/raw/master/cs-x86_64-pc-win32.zip")
    (`darwin "https://github.com/coursier/launchers/raw/master/cs-x86_64-apple-darwin.gz")
    (_ "https://github.com/coursier/launchers/raw/master/cs-x86_64-pc-linux.gz"))
  "Download url for coursier."
  :group 'lsp-metals
  :type 'string
  :package-version '(lsp-metals . "1.2"))

(defcustom lsp-metals-coursier-decompress
  (pcase system-type
    (`windows-nt :zip)
    (_ :gzip))
  "Compression type of the downloaded coursier binary."
  :group 'lsp-metals
  :type 'string
  :package-version '(lsp-metals . "1.3"))

(defcustom lsp-metals-install-version "latest.release"
  "Metals version to install."
  :group 'lsp-metals
  :type 'string
  :package-version '(lsp-metals . "1.2"))

(defcustom lsp-metals-java-home ""
  "The Java Home directory.
It's used for indexing JDK sources and locating the `java' binary."
  :type '(string)
  :group 'lsp-metals
  :package-version '(lsp-metals . "1.0"))

(defcustom lsp-metals-scalafmt-config-path ""
  "Optional custom path to the .scalafmt.conf file.
Should be relative to the workspace root directory and use forward
slashes / for file separators (even on Windows)."
  :type '(string)
  :group 'lsp-metals
  :package-version '(lsp-metals . "1.0"))

(defcustom lsp-metals-sbt-script ""
  "Optional absolute path to an `sbt' executable.
By default, Metals uses `java -jar sbt-launch.jar' with an embedded
launcher while respecting `.jvmopts' and `.sbtopts'.  Update this
setting if your `sbt' script requires more customizations like using
environment variables."
  :type '(string)
  :group 'lsp-metals
  :package-version '(lsp-metals . "1.0"))

(defcustom lsp-metals-gradle-script ""
  "Optional absolute path to a `gradle' executable.
By default, Metals uses gradlew with 5.3.1 gradle version.  Update
this setting if your `gradle' script requires more customizations like
using environment variables."
  :type '(string)
  :group 'lsp-metals
  :package-version '(lsp-metals . "1.0"))

(defcustom lsp-metals-maven-script ""
  "Optional absolute path to a `maven' executable.
By default, Metals uses mvnw maven wrapper with 3.6.1 maven version.
Update this setting if your `maven' script requires more
customizations."
  :type '(string)
  :group 'lsp-metals
  :package-version '(lsp-metals . "1.0"))

(defcustom lsp-metals-mill-script ""
  "Optional absolute path to a `mill' executable.
By default, Metals uses mill wrapper script with 0.5.0 mill version.
Update this setting if your mill script requires more customizations
like using environment variables."
  :type '(string)
  :group 'lsp-metals
  :package-version '(lsp-metals . "1.0"))

(defcustom lsp-metals-pants-targets ""
  "Space separated list of Pants targets to export.
For example, `src/main/scala:: src/main/java::'.  Syntax such as
`src/{main,test}::' is not supported."
  :type '(string)
  :group 'lsp-metals
  :package-version '(lsp-metals . "1.0"))

(defcustom lsp-metals-bloop-sbt-already-installed nil
  "If true, Metals will not generate a `project/metals.sbt' file.
This assumes that sbt-bloop is already manually installed in the sbt
build.  Build import will fail with a 'not valid command bloopInstall`
error in case Bloop is not manually installed in the build when using
this option."
  :type 'boolean
  :group 'lsp-metals
  :package-version '(lsp-metals . "1.0"))

(defcustom lsp-metals-bloop-version nil
  "The version of Bloop to use.
This version will be used for the Bloop build tool plugin, for any
supported build tool, while importing in Metals as well as for running
the embedded server."
  :type '(choice
          (const :tag "Default" nil)
          (string :tag "Version"))
  :group 'lsp-metals
  :package-version '(lsp-metals . "1.0"))

(defcustom lsp-metals-super-method-lenses-enabled nil
  "If True, super method lenses will be shown.
Super method lenses are visible above methods definition that override
another methods.  Clicking on a lens jumps to super method definition.
Disabled lenses are not calculated for opened documents which might
speed up document processing."
  :type 'boolean
  :group 'lsp-metals
  :package-version '(lsp-metals . "1.0"))

(defcustom lsp-metals-show-implicit-arguments nil
  "If True, implicit argument annotations will be shown.
When this option is enabled, each method that has implicit arguments has them
displayed either as additional decorations."
  :type 'boolean
  :group 'lsp-metals
  :package-version '(lsp-metals . "1.2"))

(defcustom lsp-metals-show-implicit-conversions-and-classes nil
  "If True, implicit conversions and classes will be shown.
When this option is enabled, each place where an implicit method or class is
used has it displayed either as additional decorations."
  :type 'boolean
  :group 'lsp-metals
  :package-version '(lsp-metals . "1.2"))

(defcustom lsp-metals-show-inferred-type nil
  "If True, inferred type annotations will be shown.
When this option is enabled, each method that can have inferred types has them
displayed either as additional decorations."
  :type 'boolean
  :group 'lsp-metals
  :package-version '(lsp-metals . "1.2"))

(defcustom lsp-metals-remote-language-server ""
  "A URL pointing to a remote language server."
  :type '(string)
  :group 'lsp-metals
  :package-version '(lsp-metals . "1.0"))

(defface lsp-metals-face-overlay
  '((t :inherit font-lock-comment-face))
  "Face used for metals decoration overlays."
  :group 'lsp-metals)

(lsp-register-custom-settings
 '(("metals.java-home" lsp-metals-java-home)
   ("metals.scalafmt-config-path" lsp-metals-scalafmt-config-path)
   ("metals.sbt-script" lsp-metals-sbt-script)
   ("metals.gradle-script" lsp-metals-gradle-script)
   ("metals.maven-script" lsp-metals-maven-script)
   ("metals.mill-script" lsp-metals-mill-script)
   ("metals.pants-targets" lsp-metals-pants-targets)
   ("metals.bloop-sbt-already-installed" lsp-metals-bloop-sbt-already-installed t)
   ("metals.bloop-version" lsp-metals-bloop-version)
   ("metals.super-method-lenses-enabled" lsp-metals-super-method-lenses-enabled t)
   ("metals.show-implicit-arguments" lsp-metals-show-implicit-arguments t)
   ("metals.show-implicit-conversions-and-classes" lsp-metals-show-implicit-conversions-and-classes t)
   ("metals.show-inferred-type" lsp-metals-show-inferred-type t)
   ("metals.remote-language-server" lsp-metals-remote-language-server)))

(lsp-dependency
 'coursier
 '(:system "cs")
 '(:system "coursier")
 `(:download :url ,lsp-metals-coursier-download-url
             :store-path ,lsp-metals-coursier-store-path
             :decompress ,lsp-metals-coursier-decompress
             :set-executable? t))

(lsp-dependency
 'metals
 `(:system ,lsp-metals-server-command)
 `(:system ,lsp-metals-metals-store-path))

(defun lsp-metals--server-command ()
  "Generate the Scala language server startup command."
  `(,(lsp-package-path 'metals) ,@lsp-metals-server-args))

(defun lsp-metals--download-server (_client callback error-callback _update?)
  "Install metals server via coursier.
Will invoke CALLBACK on success, ERROR-CALLBACK on error."
  (lsp-package-ensure
   'coursier
   (lambda ()
     (call-process
      (lsp-package-path 'coursier)
      nil
      (get-buffer-create "*Coursier log*")
      t
      "bootstrap"
      "--java-opt"
      "-Xss4m"
      "--java-opt"
      "-Xms100m"
      (concat "org.scalameta:metals_2.12:" lsp-metals-install-version)
      "-r"
      "bintray:scalacenter/releases"
      "-r"
      "sonatype:snapshots"
      "-o"
      lsp-metals-metals-store-path
      "-f")
     (funcall callback))
   error-callback))

(defun lsp-metals-build-import ()
  "Unconditionally run `sbt bloopInstall` and re-connect to the build server."
  (interactive)
  (lsp-metals-treeview--send-execute-command-async "build-import" ()))

(defun lsp-metals-build-connect ()
  "Unconditionally cancel existing build server connection and re-connect."
  (interactive)
  (lsp-metals-treeview--send-execute-command-async "build-connect" ()))

(defun lsp-metals-cancel-compilation ()
  "Cancel the currently ongoing compilation, if any."
  (interactive)
  (lsp-metals-treeview--send-execute-command-async "compile-cancel" ()))

(defun lsp-metals-cascade-compile ()
  "Cascade compile all open files."
  (interactive)
  (lsp-metals-treeview--send-execute-command-async "compile-cascade"))

(defun lsp-metals-clean-compile ()
  "Recompile all build targets in this workspace."
  (interactive)
  (lsp-metals-treeview--send-execute-command-async "compile-clean"))

(defun lsp-metals-restart-build-server ()
  "Unconditionally stop the current running Bloop server and start a new one."
  (interactive)
  (lsp-metals-treeview--send-execute-command-async "build-restart"))

(defun lsp-metals-new-scala-file ()
  "Create a new file either a class, object, trait, package object or worksheet."
  (interactive)
  (lsp--send-execute-command "new-scala-file" (concat "file://" default-directory)))

(defun lsp-metals-new-scala-project ()
  "Create a new Scala project using one of the available g8 templates."
  (interactive)
  (lsp--send-execute-command "new-scala-project"))

(defun lsp-metals-doctor-run ()
  "Open the Metals doctor to troubleshoot potential build problems."
  (interactive)
  (lsp-send-execute-command "doctor-run" ()))

(defun lsp-metals-sources-scan ()
  "Walk all files in the workspace and index where symbols are defined."
  (interactive)
  (lsp-metals-treeview--send-execute-command-async "sources-scan" ()))

(defun lsp-metals-reset-choice ()
  "Reset a decision you made about different settings.
E.g. If you choose to import workspace with sbt you can decide to reset and
change it again."
  (interactive)
  (lsp-send-execute-command "reset-choice" ()))

(defun lsp-metals-copy-worksheet-output ()
  "Copy worksheet with evaluated results as comments."
  (interactive)
  (let ((command-result (lsp-send-execute-command "metals.copy-worksheet-output" (lsp--buffer-uri))))
    (when-let ((value (lsp-get command-result :value)))
      (kill-new value)
      (message "Copied worksheet output."))))

(defun lsp-metals-analyze-stacktrace ()
  "Convert provided stacktrace in the region to a format with links."
  (interactive)
  (when (and (use-region-p) default-directory)
    (with-lsp-workspace (lsp-find-workspace 'metals default-directory)
      (let ((stacktrace (buffer-substring (region-beginning) (region-end))))
        (lsp-send-execute-command "metals.analyze-stacktrace" (vector stacktrace))))))

(defun lsp-metals-super-method-hierarchy ()
  "Calculate inheritance hierarchy of a class that should contain given method."
  (interactive)
  (lsp-send-execute-command
   "super-method-hierarchy"
   (lsp--text-document-position-params)))

(defun lsp-metals-goto-super-method ()
  "Jumps to super method/field definition of a symbol under cursor."
  (interactive)
  (lsp-send-execute-command
   "goto-super-method"
   (lsp--text-document-position-params)))

(defun lsp-metals--generate-decode-file-buffer-name (name format-id)
  "Generate DecodeFile buffer name for the given FORMAT-ID and NAME."
  (format "*%s: %s*" format-id name))

(defun lsp-metals-decode-file (format-id)
  "View the decoded representation of the given FORMAT-ID for the current buffer."
  (when-let* ((encoded-path (format "metalsDecode:%s.%s" (lsp--buffer-uri) format-id))
              (command-result (lsp-send-execute-command "metals.file-decode" encoded-path))
              (value (lsp-get command-result :value)))
    (pop-to-buffer (lsp-metals--generate-decode-file-buffer-name buffer-file-name format-id))
    (setq-local show-trailing-whitespace nil)
    (setq-local buffer-read-only nil)
    (erase-buffer)
    (insert value)
    (goto-char (point-min))
    (view-mode 1)
    (setq view-exit-action 'kill-buffer)))

(defun lsp-metals-view-javap ()
  "View javap for a class in the current file."
  (interactive)
  (lsp-metals-decode-file "javap"))

(defun lsp-metals-view-javap-verbose ()
  "View javap verbose a class in the for current file."
  (interactive)
  (lsp-metals-decode-file "javap-verbose"))

(defun lsp-metals-view-semanticdb-compact ()
  "View semanticdb compact for current file."
  (interactive)
  (lsp-metals-decode-file "semanticdb-compact"))

(defun lsp-metals-view-semanticdb-detailed ()
  "View semanticdb detailed for current file."
  (interactive)
  (lsp-metals-decode-file "semanticdb-detailed"))

(defun lsp-metals-view-tasty-decoded ()
  "View tasty decoded for current file."
  (interactive)
  (lsp-metals-decode-file "tasty-decoded"))

(defun lsp-metals--doctor-render (html)
  "Render the Metals doctor HTML in the current buffer."
  (require 'shr)
  (setq-local show-trailing-whitespace nil)
  (setq-local buffer-read-only nil)
  (erase-buffer)
  (insert html)
  (shr-render-region (point-min) (point-max))
  (goto-char (point-min))
  (view-mode 1)
  (setq view-exit-action 'kill-buffer))

(defun lsp-metals--generate-doctor-buffer-name (workspace)
  "Generate doctor buffer name for the WORKSPACE."
  (format "*Metals Doctor: %s*" (process-id (lsp--workspace-cmd-proc workspace))))

(defun lsp-metals--doctor-run (workspace html)
  "Focus on a window displaying troubleshooting help from the Metals doctor.
HTML is the help contents.
WORKSPACE is the workspace the client command was received from."
  (pop-to-buffer (lsp-metals--generate-doctor-buffer-name workspace))
  (lsp-metals--doctor-render html))

(defun lsp-metals--doctor-reload (workspace html)
  "Reload the HTML contents of an open Doctor window, if any.
Should be ignored if there is no open doctor window.
WORKSPACE is the workspace the client command was received from."
  (when-let ((buffer (get-buffer (lsp-metals--generate-doctor-buffer-name workspace))))
    (with-current-buffer buffer
      (lsp-metals--doctor-render html))))

(defun lsp-metals--goto-location (_workspace location &optional _)
  "Move the cursor focus to the provided LOCATION."
  (let ((xrefs (lsp--locations-to-xref-items (list location))))
    (if (boundp 'xref-show-definitions-function)
      (with-no-warnings
        (funcall xref-show-definitions-function
          (-const xrefs)
          `((window . ,(selected-window)))))
      (xref--show-xrefs xrefs nil))))

(defun lsp-metals--echo-command (workspace command)
  "A client COMMAND that should be forwarded back to the Metals server.
WORKSPACE is the workspace the client command was received from."
  (with-lsp-workspace workspace
    (lsp-send-execute-command command)))

(defun lsp-metals-bsp-switch ()
  "Interactively switch between BSP servers."
  (interactive)
  (lsp-send-execute-command "bsp-switch" ()))

(defun lsp-metals-generate-bsp-config ()
  "Generate a Scala BSP Config based on the current BSP server."
  (interactive)
  (lsp-send-execute-command "generate-bsp-config" ()))

(lsp-defun lsp-metals--publish-decorations (workspace (&PublishDecorationsParams :uri :options))
  "Handle the metals/publishDecorations extension notification.
WORKSPACE is the workspace the notification was received from."
  (with-lsp-workspace workspace
    (let* ((file (lsp--uri-to-path uri))
            (buffer (find-buffer-visiting file)))
      (when buffer
        (with-current-buffer buffer
          (lsp--remove-overlays 'metals-decoration)
          (mapc #'lsp-metals--make-overlay options))))))

(lsp-defun lsp-metals--make-overlay ((&DecorationOptions :range :render-options :hover-message?))
  "Create overlay from metals decoration."
  (let* ((region (lsp--range-to-region range))
          (ov (make-overlay (car region) (cdr region) nil t t)))
    (-when-let* (((&ThemableDecorationInstanceRenderOption :after?) render-options)
                  ((&ThemableDecorationAttachmentRenderOptions :content-text?) after?))
      (overlay-put ov 'after-string (propertize content-text? 'cursor t 'font-lock-face 'lsp-metals-face-overlay)))
    (when hover-message?
      (-let (((&MarkupContent :value) hover-message?))
        (overlay-put ov 'help-echo value)))
    (overlay-put ov 'metals-decoration t)))

(defun lsp-metals--logs-toggle (_workspace)
  "Toggle focus on the logs reported by the server via `window/logMessage'."
  (switch-to-buffer (get-buffer-create "*lsp-log*")))

(defun lsp-metals--diagnostics-focus (_workspace)
  "Focus on the window that lists all published diagnostics."
  (lsp-treemacs-errors-list))

(lsp-defun lsp-metals--execute-client-command (workspace (&ExecuteCommandParams :command :arguments?))
  "Handle the metals/executeClientCommand extension notification.
WORKSPACE is the workspace the notification was received from."
  (when-let ((command (pcase command
                        (`"metals-doctor-run" #'lsp-metals--doctor-run)
                        (`"metals-doctor-reload" #'lsp-metals--doctor-reload)
                        (`"metals-logs-toggle" #'lsp-metals--logs-toggle)
                        (`"metals-diagnostics-focus" #'lsp-metals--diagnostics-focus)
                        (`"metals-goto-location" #'lsp-metals--goto-location)
                        (`"metals-echo-command" #'lsp-metals--echo-command)
                        (`"metals-model-refresh" #'lsp-metals--model-refresh)
                        (c (ignore (lsp-warn "Unknown metals client command: %s" c))))))
    (apply command (append (list workspace) arguments? nil))))

(defvar lsp-metals--current-buffer nil
  "Current buffer used to send `metals/didFocusTextDocument' notification.")

(defun lsp-metals--window-state-did-change (focused)
  "Send `metals/windowStateDidChange' notification on frames focus change.
FOCUSED if there is a focused frame."
  (lsp-notify "metals/windowStateDidChange" `((focused . ,focused))))

(defun lsp-metals--workspaces ()
  "Get the list of all metals workspaces."
  (--filter
   (eq (lsp--client-server-id (lsp--workspace-client it)) 'metals)
   (lsp--session-workspaces (lsp-session))))

(defmacro lsp-metals--add-focus-hooks ()
  "Add hooks for `metals/windowStateDidChange' notification."
  (if (boundp 'after-focus-change-function)
      `(progn
         (defun lsp-metals--handle-focus-change ()
           "Send `metals/windowStateDidChange' notification on frames focus change."
           (let ((focused (if (and (fboundp 'frame-focus-state) (frame-focus-state)) t :json-false)))
             (--each (lsp-metals--workspaces)
               (with-lsp-workspace it
                 (lsp-metals--window-state-did-change focused)))))
         (add-function :after after-focus-change-function 'lsp-metals--handle-focus-change))
    `(progn
       (defun lsp-metals--focus-in-hook ()
         "Send `metals/windowStateDidChange' notification when a frame gains focus."
         (--each (lsp-metals--workspaces)
           (with-lsp-workspace it
             (lsp-metals--window-state-did-change t))))
       (add-hook 'focus-in-hook 'lsp-metals--focus-in-hook)
       (defun lsp-metals--focus-out-hook ()
         "Send `metals/windowStateDidChange' notification when all frames lost focus."
         (--each (lsp-metals--workspaces)
           (with-lsp-workspace it
             (lsp-metals--window-state-did-change :json-false))))
       (add-hook 'focus-out-hook 'lsp-metals--focus-out-hook))))

(defun lsp-metals--did-focus ()
  "Send `metals/didFocusTextDocument' on buffer switch."
  (unless (eq lsp-metals--current-buffer (current-buffer))
    (setq lsp-metals--current-buffer (current-buffer))
    (lsp-notify "metals/didFocusTextDocument" (lsp--buffer-uri))))


(defun lsp-metals-populate-config (conf)
  "Prepare CONF for debug session."
  (if (and (plist-get conf :debugServer)
           (plist-get conf :name))
      conf
    (-let (((&DebugSession :name :uri)
            (lsp-send-execute-command
             "debug-adapter-start"
             (vector (list :data conf
                           :dataKind (cond
                                      ((equal "attach" (plist-get conf :request))
                                       "scala-attach-remote")
                                      ((plist-get conf :dataKind))
                                      (t "scala-main-class"))
                           :targets (or
                                     (plist-get conf :targets)
                                     (vector `(:uri ,(concat
                                                      (lsp--path-to-uri (or (lsp-workspace-root)
                                                                            (error "The debug provide can be called under project root")))
                                                      "?id="
                                                      (or
                                                       (plist-get conf :buildTarget)
                                                       "root"))))))))))
      (-> conf
          (dap--put-if-absent :name name)
          (dap--put-if-absent :request "launch")
          (dap--put-if-absent :host (or "localhost"
                                        (plist-get conf :hostName)))
          (dap--put-if-absent :debugServer
                              (-> uri
                                  (split-string ":")
                                  cl-third
                                  string-to-number))))))


(dap-register-debug-provider "scala" #'lsp-metals-populate-config)

(dap-register-debug-template
 "Scala Main Class"
 '(:type "scala" :class "<main.class>" :name "Scala Main Class" :arguments [] :jvmOptions [] :environmentVariables []))

(dap-register-debug-template
 "Scala Attach"
 '(:type "scala" :request "attach" :name "Scala Attach" :hostName "localhost" :port 0))


(lsp-defun lsp-metals--debug-start (no-debug (&Command :arguments?))
  "Start debug session.
If NO-DEBUG is true launch the program without enabling debugging.
PARAMS are the action params."
  ;; make sure the arguments are plist
  (-let (((&DebugSession :name :uri) (lsp-send-execute-command
                                      "debug-adapter-start"
                                      arguments?)))
    (dap-debug
     (list :debugServer (-> uri
                            (split-string ":")
                            cl-third
                            string-to-number)
           :type "scala"
           :name name
           :host "localhost"
           :request "launch"
           :noDebug no-debug))))

(defun lsp-metals--model-refresh (workspace)
  "Handle `metals-model-refresh' notification refreshing lenses.
WORKSPACE is the workspace the notification was received from."
  (->> workspace
       (lsp--workspace-buffers)
       (mapc (lambda (buffer)
               (with-current-buffer buffer
                 (when (bound-and-true-p lsp-lens-mode)
                   (lsp-lens--schedule-refresh t)))))))

(defun lsp-metals--status-string-keymap (workspace command?)
  "Keymap for `metals/status' notification.
WORKSPACE is the workspace we received notification from.
COMMAND is the client command to execute."
  (when command?
    (-doto (make-sparse-keymap)
      (define-key [mode-line mouse-1]
        (lambda ()
          (interactive)
          (lsp-metals--execute-client-command workspace (lsp-make-execute-command-params :command command?)))))))

(lsp-defun lsp-metals--status-string (workspace (&MetalsStatusParams :text :hide? :tooltip? :command?))
  "Handle `metals/status' notification.
WORKSPACE is the workspace we received notification from."
  (if (or hide? (s-blank-str? text))
    (lsp-workspace-status nil workspace)
    (lsp-workspace-status (propertize text
                            'help-echo tooltip?
                            'local-map (lsp-metals--status-string-keymap workspace command?))
      workspace)))

(lsp-defun lsp-metals--quick-pick (_workspace (&MetalsQuickPickParams :items :place-holder?))
  "Provide a string value by picking from given options."
  (let* ((choices (seq-map (lambda (item)
                             (-let* (((&MetalsQuickPickItem :id :label :description?) item))
                               (cons (if description?
                                         (concat label " " (propertize description? 'face 'font-lock-comment-face))
                                       label)
                                     id)))
                           items)))
    (if choices
        (list :itemId (cdr (assoc (completing-read (concat place-holder? ": ") choices nil t) choices))))))

(lsp-defun lsp-metals--input-box (_workspace (&MetalsInputBoxParams :prompt))
  "Provide a string value for a given prompt."
  (list :value (read-from-minibuffer (concat prompt ": "))))

(lsp-register-client
 (make-lsp-client :new-connection (lsp-stdio-connection 'lsp-metals--server-command)
                  :major-modes '(scala-mode)
                  :priority -1
                  :initialization-options '((decorationProvider . t)
                                            (inlineDecorationProvider . t)
                                            (didFocusProvider . t)
                                            (executeClientCommandProvider . t)
                                            (doctorProvider . "html")
                                            (statusBarProvider . "on")
                                            (debuggingProvider . t)
                                            (treeViewProvider . t)
                                            (quickPickProvider . t)
                                            (inputBoxProvider . t))
                  :notification-handlers (ht ("metals/executeClientCommand" #'lsp-metals--execute-client-command)
                                             ("metals/publishDecorations" #'lsp-metals--publish-decorations)
                                             ("metals/treeViewDidChange" #'lsp-metals-treeview--did-change)
                                             ("metals-model-refresh" #'lsp-metals--model-refresh)
                                             ("metals/status" #'lsp-metals--status-string))
                  :request-handlers (ht ("metals/quickPick" #'lsp-metals--quick-pick)
                                        ("metals/inputBox" #'lsp-metals--input-box))
                  :action-handlers (ht ("metals-debug-session-start" (-partial #'lsp-metals--debug-start :json-false))
                                       ("metals-run-session-start" (-partial #'lsp-metals--debug-start t)))
                  :server-id 'metals
                  :initialized-fn (lambda (workspace)
                                    (lsp-metals--add-focus-hooks)
                                    (with-lsp-workspace workspace
                                      (lsp--set-configuration
                                       (lsp-configuration-section "metals"))))
                  :after-open-fn (lambda ()
                                   (add-hook 'lsp-on-idle-hook #'lsp-metals--did-focus nil t))
                  :completion-in-comments? t
                  :download-server-fn #'lsp-metals--download-server))

(defmacro lsp-metals--create-bool-toggle (name config var)
  "Create a toggle for lsp-metal config.
NAME is a user-facing name used for the interactive command.  CONFIG is the LSP
configuration name.  VAR is the variable holding the value of the configuration."
  (let ((func-name (intern (format "lsp-metals-toggle-%s" name))))
    `(defun ,func-name ()
       ,(format "Toggle LSP metals %s config" name)
      (interactive)
      (setq ,var (not ,var))
      (lsp-register-custom-settings '((,(format "metals.%s" config) ,var t)))
      (with-lsp-workspaces (lsp-metals--workspaces)
        (lsp--set-configuration (lsp-configuration-section "metals")))
      (let ((status (if ,var "on" "off")))
        (lsp--info "Turned %s %s" status ,name)))))

(lsp-metals--create-bool-toggle "show-inferred-type" "show-inferred-type" lsp-metals-show-inferred-type)
(lsp-metals--create-bool-toggle "show-implicit-arguments" "show-implicit-arguments" lsp-metals-show-implicit-arguments)
(lsp-metals--create-bool-toggle "show-super-method-lenses" "super-method-lenses-enabled" lsp-metals-super-method-lenses-enabled)
(lsp-metals--create-bool-toggle "show-implicit-conversions" "show-implicit-conversions-and-classes" lsp-metals-show-implicit-conversions-and-classes)

(provide 'lsp-metals)
;;; lsp-metals.el ends here

;; Local Variables:
;; End:
