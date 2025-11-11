;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Base: 10 -*-

(defpackage :skald-system
  (:use :cl :asdf))

(in-package :skald-system)

(defsystem :skald
  :depends-on (:bifrost)
  :description "Part of the OLD-NORSE Terminal Toolkit. High-level terminal UI library built on BIFROST. Optimized for fast screen redrawing with minial flicker."
  :author "Nick Allen <nallen05@gmail.com>"
  :version "0.1"
  :components
  ((:module :skald
            :components ((:file skald2))
            :serial t)))

(defsystem :skald/test
  :depends-on (:skald :swordbreaker)
  :description "tests for SKALD"
  :author "Nick Allen <nallen05@gmail.com>"
  :version "0.1"
  :components
  ((:module :skald
    :components ((:file test-buffer)
                 (:file test-layout))
    :serial t)))


(format t "~%~A" *load-truename*)

(uiop:pathname-directory-pathname (asdf:system-definition-pathname (asdf:find-system "swordbreaker")))
