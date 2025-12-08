

(defpackage :bifrost
  (:use :cl)
  (:export  ;; raw IO
            :with-bifrost
            :*bifrost-tty-p*
            :*bifrost-io*

            ;; writing to the terminal
            :bifrost-write
            
            ;; reading from the terminal
            :bifrost-read
            :bifrost-read-no-hang
            :bifrost-listen
            :*rune*                                    ;; changed
            :*rune-payload*                            ;; eventually to be depricated
            :*rune-container*                          ;; eventually to be depricated
            :*bifrost-read-escape-sequence-max-hang*
            :*bifrost-suppress-outside-tty-warnings*

;;            ;; dispatching control flow based on runes
;;            :rune-case
                         
            ;; tracking mouse events
	          :with-mouse-tracking
            :*bifrost-mouse-tracking-mode*

	          ;; defining CBOX click regions
            :with-cbox-layer
            :register-cbox!
            
 	          ;; what CBOX is being interactived with?
            :*pressed-cbox*
            :*hover-cbox*

            ;; debugging modes
            :*bifrost-debug-mode*
            :*bifrost-read-debug-literal-char*
            
            ;; inxpecting the cbox stack
            :find-cbox
            :*cbox-stack*

            ;; the cbox containers
            :cbox-container
      	    :cbox-container-p
            :cbox-container-payload
;;            :cbox-events
            :cbox-container-min-row
            :cbox-container-min-column
            :cbox-container-max-row
            :cbox-container-max-column
            :*pressed-cbox-container*
            :*hover-cbox-container*

            
            ;; advanced mode
            :bifrost-write-raw
            :bifrost-read-raw
            :bifrost-read-raw-no-hang
	    ))

(in-package :bifrost)


;; raw interaction with the terminal

(defvar *bifrost-tty-p*)
(defvar *bifrost-io*)

(defun init-bifrost-io ()
  (let* ((input-stream (etypecase sb-sys:*tty*
                         (sb-sys:fd-stream sb-sys:*tty*)
                         (two-way-stream (two-way-stream-input-stream sb-sys:*tty*))))
         (fd (sb-sys:fd-stream-fd input-stream)))
    (setf *bifrost-tty-p*
          (when (plusp (sb-unix:unix-isatty fd))
            fd)
          
          *bifrost-io*
          (if *bifrost-tty-p*
              sb-sys:*tty*
              *terminal-io*))))

(defun clear-bifrost-io (&optional (stream *bifrost-io*))
  "Clear buffered input & output"
  (etypecase stream
    (synonym-stream (clear-bifrost-io (symbol-value (synonym-stream-symbol stream))))
    (sb-sys:fd-stream
     (finish-output stream)
     (loop while (listen stream)
           do (read-char-no-hang stream)))
    (two-way-stream
     (finish-output (two-way-stream-output-stream stream))
     (let ((input (two-way-stream-input-stream stream)))
       (loop while (listen input)
             do (read-char-no-hang input))))))

(defvar *bifrost-suppress-outside-tty-warnings* nil)

(defun warn-if-outside-terminal ()
  (unless (or *bifrost-tty-p*
              *bifrost-suppress-outside-tty-warnings*)
    (warn "We're outside of a Unix-like terminal emulator. Entering \"read-debug\" mode. To send input to BIFROST, you must force with a newline, similar to READ-LINE, in order to bypass any read buffers in the way of raw IO. See also: *BIFROST-DEBUG-MODE* & *BIFROST-SUPPRESS-OUTSIDE-TTY-WARNINGS")
    (finish-output *error-output*)))


;; bifrost read buffer - needed to unread sequences of multiple characters

(defstruct fifo-char-buffer
  first
  last)

(defparameter *bifrost-read-buffer* (make-fifo-char-buffer))

(defun prepend-fifo-char-buffer (char-or-charlist fifo) ;; put it at the beggining
  (when char-or-charlist
    (let* ((%charlist (if (listp char-or-charlist)
			                    char-or-charlist
			                    (list char-or-charlist)))
	         (%charlist-last (last %charlist)))
      (if (fifo-char-buffer-first fifo)
	        (setf (rest %charlist-last)
		            (fifo-char-buffer-first fifo)
		            (fifo-char-buffer-first fifo)
		            %charlist)
	        (setf (fifo-char-buffer-first fifo)
		            %charlist
		            (fifo-char-buffer-last fifo)
		            %charlist-last))))
  fifo)

(defun append-fifo-char-buffer (char-or-charlist fifo) ;; put it at the end
  (when char-or-charlist
    (let* ((%charlist (if (listp char-or-charlist)
			                    char-or-charlist
			                    (list char-or-charlist)))
	         (%charlist-last (last %charlist)))
      (if (fifo-char-buffer-first fifo)
	        (setf (rest (fifo-char-buffer-last fifo))
		            %charlist
		            (fifo-char-buffer-last fifo)
		            %charlist-last)
	        (setf (fifo-char-buffer-first fifo)
		            %charlist
		            (fifo-char-buffer-last fifo)
		            %charlist-last))))
  fifo)

(defun pop-fifo-char-buffer (fifo)
  (when (fifo-char-buffer-first fifo)
    (if (eq (fifo-char-buffer-first fifo)
	          (fifo-char-buffer-last fifo))
	      (let ((ret (pop (fifo-char-buffer-first fifo))))
	        (setf (fifo-char-buffer-last fifo)
		            nil)
	        ret)
	      (pop (fifo-char-buffer-first fifo)))))

(defun bifrost-listen ()
  (or (fifo-char-buffer-first *bifrost-read-buffer*)
      (listen *bifrost-io*)))

(defun reset-fifo-char-buffer (&optional (fifo *bifrost-read-buffer*))
  (setf (fifo-char-buffer-first fifo) nil
        (fifo-char-buffer-last fifo)  nil)
  fifo)


;; whitelist of known RUNES
;; defined here for passing rune literals when in testing mode

(defparameter *bifrost-read-literal-whitelist*
  '(:up-arrow
    :down-arrow
    :right-arrow
    :left-arrow
    :window-size
    :mouse-click-left
    :mouse-click-middle
    :mouse-click-right
    :mouse-release
    :mouse-move))           ;; mouse-move, mouse-drag-left/middle/right
    
 
;; Reading from the terminal
  
(defparameter *bifrost-read-debug-literal-char* #\~)

(defun %read-char-burst-no-hang (stream)
  "
like READ-CHAR-NO-HANG except that if multiple characters are buffered to be read from STREAM
then all of them are read & it returns a list of characters instead of a single character

this function should only be called within BIFROST:WITH-BIFROST, which sets a special flag
*BIFROST-TTY-P*

If *BIFROST-TTY-P* is truthy, that indicates that we're inside a Unix-like TTY & that
WITH-BIFROST has enabled TRIVIAl-RAW-IO:WITH-RAW-IO. In this mode, then %READ-CHAR-BURST-NO-HANG
is more likely to return an atom like NIL (nothing to read) or a single character. But it is
still possible to return multiple characters if they were typed very quickly & are sitting in
 the input buffer.

If we're NOT inside of a Unix-like TTY, then we enter a special read-debug mode that causes
this  function to behaves closer to CL:READ-LINE
  a #\newline -> #\a
  a b c #\newline -> (#\a #\b #\c)

Read-debug mode supports 2 special cases
  1. a single newline is interpreted as #\newline:
     #\newline -> #\newline
  2. the special character *bifrost-read-debug-literal-char* (which defaults to #\~) allows you to
enter a rune literal
     ~ :up-arrow -> :UP-ARROW
     ~ (:move-cursor 1 1) -> (:MOVE-CURSOR 1 1)
the special character is configurable via *BIFROST-READ-DEBUG-LITERAL-CHAR*
the special character must be the FIRST character of the buffered line to work:
  a b ~ :up-arrow -> (#\a #\b #\~ #\: #\u #\p #\- #\a #\r #\r #\o #\w)
if the special character is triggered, %READ-CHAR-BURST-NO-HANG also returns a second value: T
"
  (assert *within-with-bifrost-form*)
  (if *bifrost-tty-p*

      ;; we're in a Unix-like terminal that implmenets standard TTY. Enter no hang mode
      (let ((c1 (read-char-no-hang stream nil nil)))
        (when c1
          (let ((c2 (read-char-no-hang stream nil nil)))
            (if c2
                (let ((accum (list c2 c1)))
                  (loop
                    (let ((cn (read-char-no-hang stream nil nil)))
                      (if cn
                          (push cn accum)
                          (return-from %read-char-burst-no-hang
                            (nreverse accum))))))
                c1))))

      ;; we're not in a standard TTD. we're probably in SLIME/EMACS.
      ;; Entering a special read-debug mode that looks for newlines & rune literals
      ;; read the docs to understand
      (let ((c1 (read-char stream nil nil)))
        (cond

          ;; newline, without preceding characters
          ;; treat as a newline
	        ((eql c1 #\newline)
	         #\newline)

          ;; rune literal
	        ((eql c1 *bifrost-read-debug-literal-char*)
	         (let ((bifrost-literal (read stream nil nil)))
	           (unless (or (characterp bifrost-literal)
                         (find (if (listp bifrost-literal)
					                         (first bifrost-literal)
					                         bifrost-literal)
			                         *bifrost-read-literal-whitelist*))
               (error "Encountered an unknown rune literal ~S. Valid types are ~{~S ~}" bifrost-literal *bifrost-read-literal-whitelist*))
	           (values bifrost-literal
		                 t)))

          ;; otherwise
	        (t (let ((accum (list c1)))
	             (loop
		             (let ((cn (read-char stream nil nil)))
                   (if (or (null cn)
                           (eql cn #\newline))
		                   (return-from %read-char-burst-no-hang
				                 (if (null (cdr accum))
				                     c1
				                     (nreverse accum)))
		                   (push cn accum))))))))))

(defun %read-char-no-hang (stream)
  "
like READ-CHAR-NO-HANG except that
- it checks the read buffer before reading from STREAM
- if more than one character is read from STREAM, it caches the rest in the read buffer

Like %READ-CHAR-BURST-NO-HANG, it returns a second value T when a rune literal is seen
"
  (if (fifo-char-buffer-first *bifrost-read-buffer*)
      (pop-fifo-char-buffer *bifrost-read-buffer*)
      (multiple-value-bind (burst rune-literal-p)
	        (%read-char-burst-no-hang stream)
	      (cond
          
	        ;; rune literal seen; only seen within T debug mode
	        (rune-literal-p
	         (if *bifrost-tty-p*
	             (error "Something is wrong! BIFROST::%READ-CHAR-NO-HANG encountered a rune literal seen outside of debug mode: ~S" burst)
               (values burst t)))

	        ;; single character read
	        ((characterp burst)
	         burst)

	        ;; multiple characters read
	        (t
	         (append-fifo-char-buffer (rest burst)
				                            *bifrost-read-buffer*)
	         (first burst))))))


;; escape sequences

(defvar *bifrost-read-alternate-esc-character-for-debugging* nil)

(defvar *bifrost-read-escape-sequence-max-hang* 0.1)

(defvar *%escape-sequence-encountered-characters*)

(defvar *%abort-escape-sequence-thunk*)

(defmacro with-escape-sequence (&body body)
  (let ((%block (gensym "with-escape-sequence-block")))
    `(block ,%block
       (let (*%escape-sequence-encountered-characters*)
	 (declare (special *%escape-sequence-encountered-characters*))
	 (let ((*%abort-escape-sequence-thunk*
		 (lambda ()
		   (prepend-fifo-char-buffer (nreverse *%escape-sequence-encountered-characters*)
					     *bifrost-read-buffer*)
		   (return-from ,%block 
		     #\esc))))
	   (declare (special *%abort-escape-sequence-thunk*))
	   ,@body)))))

(defun %get-next-escape-sequence-char (stream)
  (let ((start-time (get-internal-real-time))
	      (timeout-itu-duration (* *bifrost-read-escape-sequence-max-hang*
				                         internal-time-units-per-second)))
    (loop
      (multiple-value-bind (c rune-literal-p)
	        (%read-char-no-hang stream)
	      (cond

	        ;; rune literal; something is wrong if you see this...
	        (rune-literal-p
	         (error "BIFROST: something is wrong! Rune literal seen within an ASCII escape sequence: ~S"
		              c))

	        ;; time out! abort!
	        ((>= (- (get-internal-real-time)
		              start-time)
	             timeout-itu-duration)
	         (if c
	             (let ((*%escape-sequence-encountered-characters*
		                   (cons c *%escape-sequence-encountered-characters*)))
		             (declare (special *%escape-sequence-encountered-characters*))
		             (funcall *%abort-escape-sequence-thunk*))
	             (funcall *%abort-escape-sequence-thunk*)))
          
	        ;; yes! found the next escape sequence character
	        (c
	         (return c))
          
	        ;; no, not yet... keep polling
	        (t nil))))))

(defmacro with-continue-escape-sequence (stream &body cases)
  (let ((c (gensym "next-escape-sequence-char")))
    `(let ((,c (%get-next-escape-sequence-char ,stream)))
       (if ,c
	         (let ((*%escape-sequence-encountered-characters*
		               (cons ,c *%escape-sequence-encountered-characters*)))
	           (declare (special *%escape-sequence-encountered-characters*))
	           (case ,c
	             ,@cases
	             (otherwise (funcall *%abort-escape-sequence-thunk*))))
	         (funcall *%abort-escape-sequence-thunk*)))))

(defmacro with-single-byte-encoded-integer ((var stream) &body body)
  (let ((c (gensym "single-byte-encoded-integer-char")))
    `(let ((,c (%get-next-escape-sequence-char ,stream)))
       (if ,c
	         (let ((*%escape-sequence-encountered-characters*
		               (cons ,c *%escape-sequence-encountered-characters*))
		             (,var (- (char-code ,c)
			                    32)))
	           (declare (special *%escape-sequence-encountered-characters*))
	           (progn ,@body))
	         (funcall *%abort-escape-sequence-thunk*)))))

(defmacro with-sgr-encoded-integer ((var stream) &body body)
  (let ((c (gensym "sgr-integer-char"))
	      (sgr-int-chars (gensym "accum-sgr-integer-chars")))
    `(let ((*%escape-sequence-encountered-characters*
	           *%escape-sequence-encountered-characters*)
	         ,sgr-int-chars)
       (declare (special *%escape-sequence-encountered-characters*))
       (loop (let ((,c (%get-next-escape-sequence-char ,stream)))
	             (if (null ,c)
		               (funcall *%abort-escape-sequence-thunk*)
		               (case ,c
		                 ((#\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9)
		                  (push ,c *%escape-sequence-encountered-characters*)
		                  (push ,c ,sgr-int-chars))
		                 (otherwise
		                  (cond
			                  ((null ,sgr-int-chars)
			                   (push ,c *%escape-sequence-encountered-characters*)
			                   (funcall *%abort-escape-sequence-thunk*))
			                  (t
			                   (prepend-fifo-char-buffer ,c *bifrost-read-buffer*)
			                   (return 
			                     (let ((,var (read-from-string (coerce (nreverse ,sgr-int-chars)
								                                                 'string))))
			                       ,@body))))))))))))

(defun %bifrost-read-escape-sequence (stream)
  (flet ((%parse-mouse-event (button row column)
	         (list (case button
			             (0  :mouse-click-left)
			             (1  :mouse-click-middle)
			             (2  :mouse-click-right)
			             (3  :mouse-release)
			             (32 :mouse-move)     ;; mouse-drag-left
			             (33 :mouse-move)     ;; mouse-drag-middle
			             (34 :mouse-move)     ;; mouse-drag-right
			             (35 :mouse-move)
			             (otherwise (funcall *%abort-escape-sequence-thunk*)))
                 row
			           column)))
    (with-escape-sequence
      (with-continue-escape-sequence stream
	      (#\[ 
	       (with-continue-escape-sequence stream
           
	         ;; arrow key
	         (#\A (list :up-arrow))
           (#\B (list :down-arrow))
           (#\C (list :right-arrow))
           (#\D (list :left-arrow))

	         ;; response to quering terminal size
	         (#\8
	          (with-continue-escape-sequence stream
	            (#\;
	             (with-sgr-encoded-integer (rows stream)
		             (with-continue-escape-sequence stream
		               (#\;
		                (with-sgr-encoded-integer (columns stream)
		                  (with-continue-escape-sequence stream
			                  (#\t (list :terminal-size
                                   rows
				                           columns))))))))))

	         ;; mouse event, SGR mode OFF (single byte encoded integers)
	         (#\M
	          (with-single-byte-encoded-integer (button stream)
	            (with-single-byte-encoded-integer (column stream)
		            (with-single-byte-encoded-integer (row stream)
		              (%parse-mouse-event button row column)))))
           
	         ;; mouse event, SGR mode ON (multi-char encoded integers)
	         (#\<
	          (with-sgr-encoded-integer (button stream)	      
	            (with-continue-escape-sequence stream
		            (#\;
		             (with-sgr-encoded-integer (column stream)
		               (with-continue-escape-sequence stream
		                 (#\;
		                  (with-sgr-encoded-integer (row stream)
			                  (with-continue-escape-sequence stream
			                    (#\M  (%parse-mouse-event button row column))
                          
			                    ;; some terminals return a button sequence with lower case #\m
			                    ;; to indicate release. We coerce that to more standard-ish 
			                    ;; button event 35 to kludge together a compatability layer,
			                    ;; unless the event is "mouse move" from mode 1003
			                    (#\m (if (eql button 35)
				                           (%parse-mouse-event 35 row column)
				                           (%parse-mouse-event 3 row column))))))))))))))))))


(defun %bifrost-read-raw-no-hang (&optional (stream *bifrost-io*))
  (multiple-value-bind (xx rune-literal-p)
      (%read-char-no-hang stream)
    (cond

      ;; rune literal
      (rune-literal-p
       (if *bifrost-tty-p*
           (error "BIFROST: something is wrong! BIFROST::%BIFROST-READ-RAW-NO-HANG encountered a rune literal outside of read-debug mode: ~S" xx)
           xx))
        
      ;; nothing there
      ((null xx)
       nil)
      
      ;; escape sequence
      ((or (eql xx #\esc)
	         (and *bifrost-read-alternate-esc-character-for-debugging*
		            (eql xx *bifrost-read-alternate-esc-character-for-debugging*)))
       (%bifrost-read-escape-sequence stream))
     
      ;; an uninteresting character
      (t
       xx))))

(defvar *rune* nil)
(defvar *rune-payload* nil)
(defvar *rune-container* nil)

(defun bifrost-read-raw-no-hang (&optional (stream *bifrost-io*))
  (unless *within-with-bifrost-form*
    (error "BIFROST: BIFROST-READ-RAW-NO-HANG called outside of WITH-BIFROST or FLOKKR form. In order to read from the terminal, BIFROST-READ-RAW-NO-HANG needs to be within one of these forms"))
  (let ((rune (%bifrost-read-raw-no-hang stream)))
    (cond

      ;; nothing there
      ((null rune) (setf *rune* nil
                         *rune-payload* nil
                         *rune-container*  nil))

      ;; complex rune
      ((listp rune) (setf *rune* (first rune)
                          *rune-payload* (rest rune)
                          *rune-container* rune))

      ;; simple rune
      (t (setf *rune* rune
               *rune-payload* rune
               *rune-container* rune)))
    rune))

(defvar *bifrost-read-poll-frequency* 0.005
  "used only in \"debug-read\" mode, when we're outside of a Unix-like terminal emulator.")

(defun bifrost-read-raw (&optional (stream *bifrost-io*))
  (loop
    (let ((rune (bifrost-read-raw-no-hang stream)))
	    (if rune
	        (return-from bifrost-read-raw
		        rune)
          (if *bifrost-tty-p*
              (sb-sys:wait-until-fd-usable *bifrost-tty-p* :input)
              (sleep *bifrost-read-poll-frequency*))))))



;; convenience

;; (defmacro rune-case (rune &body cases)
;;   (let ((%rune (gensym "rune"))
;;         (%rune-name (gensym "rune-name")))
;;     `(let* ((,%rune ,rune)
;;             (,%rune-name (if (listp ,%rune)
;;                              (first ,%rune)
;;                              ,%rune)))
;;        (cond
;;          ,@(mapcar (lambda (clause)
;;                      (destructuring-bind (key . forms)
;;                          clause
;;                        (cond
;;                          ((eql key 'otherwise)
;;                           `(t ,@forms))
;;                          ((null key)
;;                           `((null ,%rune) ,@forms))
;;                          ((or (characterp key)
;;                               (keywordp key))
;;                           `((eql ,%rune-name ,key) ,@forms))
;;                          ((listp key)
;;                           (cond
;;                             ((or (every #'characterp key)
;;                                  (every #'keywordp key)    )
;;                              `((find ,%rune-name ',key) ,@forms))
;;                             ((keywordp (first key))
;;                              `((equalp ,%rune-name ,key) ,@forms))
;;                             (t (error "malformed RUNE-CASE clause ~S" clause))))
;;                          (t (error "malformed RUNE-CASE clause ~S" clause)))))
;;                    cases)))))












;;;; sending escape sequences to the terminal


(defvar *bifrost-debug-mode* nil)
  ;; NIL
  ;; :human-readable
  ;; :machine-readable

(defun %send-escape-sequence (stream &rest strings-and-chars)
  (unless (eq *bifrost-debug-mode* :human-readable)
    (dolist (% strings-and-chars)
	    (etypecase   %
	      (string (write-string % stream))
	      (character (if (and (eq *bifrost-debug-mode* :machine-readable)
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

(defun bifrost-write-raw (rune-or-char &optional (stream *bifrost-io*))
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
            (otherwise (error "BIFROST-WRITE: unknown rune ~S" rune-or-char)))))))

(defun %read-query-cursor-position-response (stream)
  (bifrost-read-raw stream)
  (case *rune*
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
                      (list :cursor-position row column))))))))))))
    (otherwise (error "unable to parse query position. Bad escape sequence returned by the terminal after querying cursor position."))))

(defun bifrost-write (rune-or-char &optional (stream *bifrost-io*))
  (bifrost-write-raw rune-or-char stream)
  (case rune-or-char
    (:query-terminal-size
     (finish-output stream)
     (bifrost-read-raw stream))
    (:query-cursor-position
     (finish-output stream)
     (%read-query-cursor-position-response stream)) ;; work around odd syntax
    (otherwise nil)))









;;;; setup: turn on mouse tracking

(defvar *bifrost-mouse-tracking-mode* nil)
(defvar *bifrost-mouse-tracking-valid-events* nil)

(defmacro with-mouse-tracking ((&optional (mode 1000) stream)
				      &body body)
  (let ((%m (gensym "mouse-tracking-mode"))
	      (%s (gensym "stream")))
    `(let ((,%m ,mode)
	         (,%s (or ,stream *terminal-io*)))
       (let ((*bifrost-mouse-tracking-mode* 1000)
             (*bifrost-mouse-tracking-valid-events* (list :mouse-click-left
                                                          :mouse-release)))
         (declare (special *bifrost-mouse-tracking-mode*
                           *bifrost-mouse-tracking-valid-events*))
         (when ,%m
	         (bifrost-write (list :mouse-reporting ,%m t) ,%s)
	         (bifrost-write (list :sgr-mouse-reporting t) ,%s)
	         (force-output ,%s))
         (unwind-protect (progn ,@body)
	         (when ,%m
	           (bifrost-write (list :mouse-reporting ,%m nil) ,%s))
	         (force-output ,%s))))))





;;;; setup: defining & inspecting CBOX stack

(defvar *%within-with-cbox-p* nil)
(defvar *cbox-stack*          nil)

(defmacro with-cbox-layer (scope &body body)
  (let ((%scope (gensym "cbox-layer-scope")))
    `(let* ((,%scope ,scope)
            (*cbox-stack* (ecase ,%scope
                            (:new nil)
                            (:inherit *cbox-stack*)))
            (*%within-with-cbox-p* t))
       (declare (special *%within-with-cbox-p*
                         *cbox-stack*))
       ,@body)))

(defstruct cbox-container
  payload
  min-row
  min-column
  max-row
  max-column)

(defun register-cbox! (payload min-row min-column max-row max-column)
  (unless *%within-with-cbox-p*
    (error "REGISTER-CBOX! called outside of WITH-CBOX"))
  (assert (numberp min-row))
  (assert (numberp min-column))
  (assert (numberp max-row))
  (assert (numberp max-column))
  (push (make-cbox-container :payload payload
                             :min-row min-row
                             :min-column min-column
                             :max-row max-row
                             :max-column max-column)
        *cbox-stack*))

(defun find-cbox-container (row column)
  (when *%within-with-cbox-p*
    (assert (numberp row))
    (assert (numberp column))
    (find-if (lambda (%cbox)
               (assert (cbox-container-p %cbox))
	             (and (<= (cbox-container-min-row %cbox) row)
                    (< row (cbox-container-max-row %cbox))
		                (<= (cbox-container-min-column %cbox) column)
                    (< column (cbox-container-max-column %cbox))))
             *cbox-stack*)))

(defun find-cbox (row column)
  (let ((cc (find-cbox-container row column)))
    (when cc
      (values (cbox-container-payload cc)
              cc))))
      


;; Reading mouse click / touch screen tap events from the terminal

(defvar *hover-cbox* nil)                 ;; what is the mouse over?
(defvar *hover-cbox-container* nil)       ;; what is the mouse over?

(defvar *pressed-cbox* nil)               ;; is something being held down? (left click only)
(defvar *pressed-cbox-container* nil)     ;; is something being held down? (left click only)

(defun %bifrost-process-cbox ()
  (when *rune-container*
    (case *rune*
      ((:mouse-click-left :mouse-click-middle :mouse-click-right)
       (destructuring-bind (row column)
           *rune-payload*
         (multiple-value-bind (cbox cc)
             (find-cbox row column)
           (if cc
               (setf *pressed-cbox*           (when (eq *rune* :mouse-click-left)
                                                cbox)
                     *pressed-cbox-container* (when (eq *rune* :mouse-click-left)
                                                cc)
                     *hover-cbox*             *pressed-cbox*
                     *hover-cbox-container*   *pressed-cbox-container*
                     *rune*                   (ecase *rune*
                                                (:mouse-click-left   :cbox-click-left)
                                                (:mouse-click-middle :cbox-click-middle)
                                                (:mouse-click-right  :cbox-click-right))
                     *rune-container*         (cons *rune*
                                                    *rune-payload*))
               (setf  *pressed-cbox*           nil
                      *pressed-cbox-container* nil
                      *hover-cbox*             nil
                      *hover-cbox-container*   nil)))))
      (:mouse-release
       (destructuring-bind (row column)
           *rune-payload*
         (multiple-value-bind (cbox cc)
             (find-cbox row column)
           (when *pressed-cbox-container*
             (setf *rune* (if (equalp cbox *pressed-cbox*)
                              :cbox-release-left
                              :cbox-unclick-left)
                   *rune-container*         (cons *rune* *rune-payload*)))
           (setf *pressed-cbox*           nil
                 *pressed-cbox-container* nil
                 *hover-cbox*             cbox
                 *hover-cbox-container*   cc))))
      ((:mouse-drag-left :mouse-drag-middle :mouse-drag-right :mouse-move)
       (destructuring-bind (row column)
           *rune-payload*
         (multiple-value-bind (cbox cc)
             (find-cbox row column)
           (when cc
             (setf *rune*                   :cbox-hover
                   *rune-container*         (cons *rune*
                                                  *rune-payload*)))
           (setf *hover-cbox*             cbox
                 *hover-cbox-container*   cc))))
      (otherwise nil))))

(defun bifrost-read-no-hang ()
  (bifrost-read-raw-no-hang)
  (%bifrost-process-cbox)
  *rune-container*)

(defun bifrost-read ()
  (bifrost-read-raw)
  (%bifrost-process-cbox)
  *rune-container*)



;; WITH-BIFROST: important setup form

 (defvar *within-with-bifrost-form* nil)

(defmacro with-bifrost (&body body)
  (let ((doit (gensym "with-bifrost-body")))
    `(flet ((,doit ()
              (let ((*within-with-bifrost-form* t))
                (declare (special *within-with-bifrost-form*))           
                ,@body)))
       (unless *within-with-bifrost-form*
         (init-bifrost-io)
         (warn-if-outside-terminal)
         (reset-fifo-char-buffer)
         (clear-bifrost-io)) ; remove stray input/output
       (unwind-protect
            (if (and *bifrost-tty-p*
                     (not *within-with-bifrost-form*))
                (trivial-raw-io:with-raw-io (:vmin 0 :vtime 0)
                  (,doit))
                (,doit))
         (unless *within-with-bifrost-form*
           (clear-bifrost-io) ; ensure clean state for warnings
           (reset-fifo-char-buffer)
           (setf *pressed-cbox* nil
                 *hover-cbox* nil)
           ;; warn a second time, in case the first  was obscured by TUI output
           (warn-if-outside-terminal))))))
