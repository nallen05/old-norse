;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Base: 10 -*-

(defpackage :flokkr-system
  (:use :cl :asdf))

(in-package :flokkr-system)

(defsystem :flokkr
  :depends-on ()
  :description "a cooperative multitasking library for Common Lisp, purpose built for building interactive terminal applications"
  :author "Nick Allen <nallen05@gmail.com>"
  :version "0.1"
  :components
  ((:module :flokkr
            :components ((:file flokkr))
            :serial t)))
