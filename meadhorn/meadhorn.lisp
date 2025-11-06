


;; nc -l 5555
;; (mh "~% Hello, ~A!" "world")


#-sbcl
(error "debug-output requires SBCL (uses sb-bsd-sockets)")

(defpackage :meadhorn
  (:use :cl)
  (:export :*meadhorn-stream*
           :*meadhorn-port*
           :mh))

(in-package :meadhorn)

(defvar *meadhorn-stream* nil)
(defvar *meadhorn-port* 5555)

(defun mh (fmt-str &rest fmt-args)
  "Debug print - attempts to send, silently fails if no connection"
  (unless *meadhorn-stream*
    ;; Try to connect to listening netcat/socat
    (setf *meadhorn-stream*
          (ignore-errors
            (let ((socket (make-instance 'sb-bsd-sockets:inet-socket
                                         :type :stream
                                         :protocol :tcp)))
              (sb-bsd-sockets:socket-connect socket #(127 0 0 1) *meadhorn-port*)
              (sb-bsd-sockets:socket-make-stream socket
                                                  :input nil
                                                  :output t
                                                  :element-type 'character)))))
  
  (when *meadhorn-stream*
    (handler-case
        (progn
          (apply #'format *meadhorn-stream* fmt-str fmt-args)
;;          (terpri *meadhorn-stream*)
          (force-output *meadhorn-stream*))
      (error ()
        ;; Connection lost - clear stream, will retry next time
        (ignore-errors (close *meadhorn-stream*))
        (setf *meadhorn-stream* nil))))
  
  (values))


