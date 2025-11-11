

(defpackage :meadhorn-system
  (:use :cl :asdf))

(in-package :meadhorn-system)

(defsystem :meadhorn
  :depends-on ()
  :description "a trivial / minimal logging function, to help debug / troubleshoot ASCII art generators & terminal UI applications. Instead of printing to the screen (which disrupts the terminal output) or writing to a log file, it broadcasts log output to a unix socket, which can be read via netcat. This is just a small / trivial function: #'MEADHORN:MD, packaged via ASDF just for convenience. (Note: SBCL only. Uses SB-BSD-SOCKETS)"
  :author "Nick Allen <nallen05@gmail.com>"
  :version "0.1"
  :components
  ((:module :meadhorn
            :components ((:file meadhorn))
            :serial t)))
