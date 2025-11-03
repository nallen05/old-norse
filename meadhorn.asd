

(defpackage :meadhorn-system
  (:use :cl :asdf))

(in-package :meadhorn-system)

(defsystem :meadhorn
  :depends-on ()
  :description "a TINY minimal logging function, specifically for terminal applications. Sends log output to a unix socket, to be read with a tool like netcat. Trivially simple, packaged just for convenience. (SBCL only: uses sb-bsd-sockets)"
  :author "Nick Allen <nallen05@gmail.com>"
  :version "0.1"
  :components
  ((:module :meadhorn
            :components ((:file meadhorn))
            :serial t)))
