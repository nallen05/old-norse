

(in-package :bifrost)



;;;; sending escape sequences to the terminal


(defvar *rune-write-debug-mode* nil)
  ;; NIL
  ;; :no-control
  ;; :escape-control

(defun %send-escape-sequence (stream &rest strings-and-chars)
  (unless (eq *rune-write-debug-mode* :no-control)
    (dolist (% strings-and-chars)
	    (etypecase   %
	      (string (write-string % stream))
	      (character (if (and (eq *rune-write-debug-mode* :escape-control)
			                      (char= % #\Esc))
			                 (format stream "~Ax~X" #\\ (char-code #\Esc))
			                 (write-char % stream)))))))

(defvar *bifrost-terminal-mouse-event-tracking-enabled* nil)
  ;; NIL
  ;; 1000
  ;; 1002
  ;; 1003

(defun %enable-mouse-reporting (stream mode flag)
  (assert (or (eq mode 1000)
	            (eq mode 1002)
	            (eq mode 1003)))
  (flet ((%toggle-on ()
	   (%send-escape-sequence stream
				  #\Esc
				  (format nil "[?~Ah"  mode)))
	 (%toggle-off ()
	   (%send-escape-sequence stream
				  #\Esc
				  (format nil
					  "[?~Al"
					  *bifrost-terminal-mouse-event-tracking-enabled*))))
    (cond

      ;; disable *BIFROST-TERMINAL-MOUSE-EVENT-TRACKING-ENABLED*
      ((null flag)
       (%toggle-off)
       (setf *bifrost-terminal-mouse-event-tracking-enabled* nil))

      ;; enable MODE
      ((null *bifrost-terminal-mouse-event-tracking-enabled*)
       (%toggle-on)
       (setf *bifrost-terminal-mouse-event-tracking-enabled* mode))

      ;; enable MODE
      ;; we're already in that mode, but send anyway just in case
      ((eql *bifrost-terminal-mouse-event-tracking-enabled*
	    mode)
     (%toggle-on))

      ;; MODE != *BIFROST-TERMINAL-MOUSE-EVENT-TRACKING-ENABLED*
      ;; disable the old one, then enable the new one
      (t 
       (%toggle-off)
       (%toggle-on)
       (setf *bifrost-terminal-mouse-event-tracking-enabled* mode)))))

(defun rune-write-raw (rune-or-char &optional (stream *terminal-io*))
  (when rune-or-char
    (if (characterp rune-or-char) 
        (write-char rune-or-char stream)
        (destructuring-bind (rune-name &rest rune-payload)
            (if (keywordp rune-or-char)
                (list rune-or-char)
                rune-or-char)
          (case rune-name
            (:query-terminal-size   (%send-escape-sequence stream #\Esc "[18t"))
            (:query-cursor-position (%send-escape-sequence stream #\Esc "[6n"))
            (:clear                 (%send-escape-sequence stream #\Esc "[2J"))
            (:reset                 (%send-escape-sequence stream #\Esc "[0m"))
            (:hide-cursor           (%send-escape-sequence stream #\Esc "[?25l"))
            (:unhide-cursor         (%send-escape-sequence stream #\Esc "[?25h"))    
            (:mouse-reporting
             (destructuring-bind (mode flag)
                 rune-payload
               (%enable-mouse-reporting stream mode flag)))
            (:sgr-mouse-reporting
             (destructuring-bind (flag)
                 rune-payload               
               (%send-escape-sequence stream
                                      #\Esc
                                      (format nil "[?1006~A" (if flag
                                                                 "h"
                                                                 "l")))))
            ((:foreground :background)
             (destructuring-bind (color)
                 rune-payload
               (assert (integerp color))
               (%send-escape-sequence stream
                                      #\Esc
                                      (format nil
                                              "[~A~Am"
                                              (ecase rune-name
                                                (:foreground 3)
                                                (:background 4))
                                              color))))
            (:move-cursor
             (if (not rune-payload)
                 (%send-escape-sequence stream #\Esc "[H")
                 (destructuring-bind (row column)
                     rune-payload
                   (assert (integerp row))
                   (assert (integerp column))
                   (%send-escape-sequence stream
                                          #\Esc
                                          (format nil "[~D;~DH" row column)))))
            (:nudge-cursor
             (destructuring-bind (row column)
                 rune-payload
               (assert (integerp row))
               (assert (integerp column))
               (when (/= row 0)
                 (%send-escape-sequence stream
                                        #\Esc
                                        (format nil "[~d~A" (abs row)
                                                (if (> row 0)
                                                    "B"
                                                    "A"))))
               (when (/= column 0)
                 (%send-escape-sequence stream
                                        #\Esc
                                        (format nil "[~d~A" (abs column)
                                                (if (> column 0)
                                                    "C"
                                                    "D"))))))
            (otherwise (error "RUNE-WRITE: unknown rune ~S" rune-or-char)))))))

(defun %read-query-cursor-position-response (stream)
  (rune-case (rune-read-raw stream)
    (#\Esc
     (with-escape-sequence
       (with-continue-escape-sequence stream
	       (#\[
	        (with-sgr-encoded-integer (row stream)
	          (with-continue-escape-sequence stream
		          (#\;
		           (with-sgr-encoded-integer (column stream)
		             (with-continue-escape-sequence stream
		               (#\R
                    (return-from %read-query-cursor-position-response
                      (list :cursor-position row column)))))))))))))
  (error "unable to parse query position. Bad escape sequence returned by the terminal after querying cursor position.")
  )

(defun rune-write (rune-or-char &optional (stream *terminal-io*))
  (rune-write-raw rune-or-char stream)
  (rune-case rune-or-char
    (:query-terminal-size
     (finish-output stream)
     (rune-read-raw stream))
    (:query-cursor-position
     (finish-output stream)
     (%read-query-cursor-position-response stream)) ;; work around odd syntax
    (otherwise nil)))

