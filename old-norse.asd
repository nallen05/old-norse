;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Base: 10 -*-

(defpackage :old-norse-system
  (:use :cl :asdf))

(in-package :old-norse-system)

(defsystem :old-norse
  :depends-on (:bifrost :skald :flokkr :meadhorn)
  :description "umbrella system that loads multiple libs useful for making text-based UI, games, and ASCII art for use with TTY terminal"
  :author "Nick Allen <nallen05@gmail.com>"
  :version "0.1"
  :components
  ((:module :lib
    :components nil
    :serial t)))

(defsystem :old-norse/test
  :depends-on (:swordbreaker :skald/test)
  :description "umbrella package for running all Old Norse related testes"
  :author "Nick Allen <nallen05@gmail.com>"
  :version "0.1")
