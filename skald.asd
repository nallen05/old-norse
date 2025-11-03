;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Base: 10 -*-

(defpackage :skald-system
  (:use :cl :asdf))

(in-package :skald-system)

(defsystem :skald
  :depends-on (:bifrost)
  :description "\"Text graphics\" library for terminal emulators such as Xterm/iTerm/TTYD/Screen/SSH/etc. Features tools to work with blocks ASCII text as if they were graphical sprites, optimized screen updates for faster animations with minimal flicker, & some bells & whistles."
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
