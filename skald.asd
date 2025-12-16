;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Base: 10 -*-

(defpackage :skald-system
  (:use :cl :asdf))

(in-package :skald-system)

(defsystem :skald
  :depends-on (:bifrost)
  :description "SKALD is a high-level terminal UI and animation framework. Optimized for fast screen redrawing with minial flicker. Part of the OLD-NORSE Terminal Toolkit. "
  :author "Nick Allen <nallen05@gmail.com>"
  :version "0.1"
  :components
  ((:module :skald
            :components ((:file skald2))
            :serial t)))

(defsystem :skald/test
  :depends-on (:skald (:version :shieldwall "0.1.2"))
  :description "tests for SKALD"
  :author "Nick Allen <nallen05@gmail.com>"
  :version "0.1"
  :components
  ((:module :skald
    :components ((:file test-buffer)
                 (:file test-layout))
    :serial t)))
