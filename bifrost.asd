;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Base: 10 -*-

(defpackage :bifrost-system
  (:use :cl :asdf))

(in-package :bifrost-system)

(defsystem :bifrost
  :depends-on (:trivial-raw-io)
  :description "Low-level Common Lisp library for reading/writing ASCII escape sequences to terminal emulators such as Xterm/iTerm2/TTYD/Screen/SSH/etc. Features support for mouse click / touch screen tap events & logic to make regions of the screen clickable."
  :author "Nick Allen <nallen05@gmail.com>"
  :version "0.1"
  :components
  ((:module :bifrost
    :components ((:file package)
		             (:file read)     ;; BIFROST-RAW-READ
		             (:file write)    ;; BIFROST-WRITE
		             (:file cbox))    ;; BIFROST-READ
    :serial t)))



(defsystem :bifrost/test
  :depends-on (:bifrost :swordbreaker)
  :description "tests for bifrost"
  :author "Nick Allen <nallen05@gmail.com>"
  :version "0.1"
  :components
  ((:module :bifrost
    :components ((:file test))
    :serial t)))
