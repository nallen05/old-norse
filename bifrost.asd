;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Base: 10 -*-

(defpackage :bifrost-system
  (:use :cl :asdf))

(in-package :bifrost-system)

(defsystem :bifrost
  :depends-on (:trivial-raw-io)
  :description "Part of the OLD-NORSE Terminal Toolkit. BIFROST is a Common Lisp library for reading/writing ASCII escape sequences. Includes support for mouse event tracking."
  :author "Nick Allen <nallen05@gmail.com>"
  :version "0.1"
  :components
  ((:module :bifrost
    :components ((:file bifrost))
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
