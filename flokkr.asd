;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Base: 10 -*-

(defpackage :flokkr-system
  (:use :cl :asdf))

(in-package :flokkr-system)

(defsystem :flokkr
  :depends-on (:bifrost)
  :description "FLOKKR is a concurrency library for Common Lisp, purpose-built for building highly responsive interactive terminal applications (user dashboards, data visualization, text-based games, etc) using bifrost/skald. Requires SBCL. Part of the OLD-NORSE Terminal Toolkit."
  :author "Nick Allen <nallen05@gmail.com>"
  :version "0.4"
  :components
  ((:module :flokkr
            :components ((:file flokkr))
            :serial t)))

(defsystem :flokkr/test
  :depends-on (:flokkr (:version :shieldwall "0.1.1"))
  :description "tests for FLOKKR"
  :author "Nick Allen <nallen05@gmail.com>"
  :components
  ((:module :skald
    :components ((:file test-flokkr))
    :serial t)))
