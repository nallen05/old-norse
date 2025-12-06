

(defpackage :bifrost
  (:use :cl)
  (:export  ;; raw IO
            :*bifrost-tty-p*
            :*bifrost-io*
            :with-bifrost

            ;; writing to the terminal
            :bifrost-write
            :*bifrost-debug-mode*
            
            ;; reading from the terminal
            :bifrost-listen
            :bifrost-read
            :bifrost-read-no-hang
            :*rune*
            :*rune-name*
            :*rune-payload*
            :*bifrost-read-escape-sequence-max-hang*
            :*bifrost-suppress-outside-tty-warnings*

            ;; dispatching control flow based on runes
            :rune-case
            
            ;; debugging modes
            :*bifrost-read-debug-mode*
            :*bifrost-read-debug-literal-char*
              
            ;; tracking mouse events
	          :with-mouse-tracking
            :*bifrost-mouse-tracking-mode*

	          ;; defining CBOX click regions
            :with-cbox-layer
            :register-cbox!
	          :*cbox-min-row*
            :*cbox-min-column*
	          :*cbox-max-row*
	          :*cbox-max-column*

	          ;; reading mouse click /touch screen tap events
            :cbox
      	    :cbox-p
            :cbox-name
            :cbox-identifier
            :cbox-payload
            :cbox-events
            :cbox-min-row
            :cbox-min-column
            :cbox-max-row
            :cbox-max-column
            :cbox-pressed-p
            :lookup-cbox
            :*cbox*
            :*cbox-stack*
            :*active-cbox-pressed*

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
           ;; warn a second time, in case the first  was obscured by TUI output
           (warn-if-outside-terminal))))))


;; whitelist of known RUNES
;; defined here for passing rune literals when in T

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
    :mouse-drag-left
    :mouse-drag-middle
    :mouse-drag-right
    :mouse-move))
    
 
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
			             (32 :mouse-drag-left)
			             (33 :mouse-drag-middle)
			             (34 :mouse-drag-right)
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
(defvar *rune-name* nil)
(defvar *rune-payload* nil)

(defun bifrost-read-raw-no-hang (&optional (stream *bifrost-io*))
  (unless *within-with-bifrost-form*
    (error "BIFROST: BIFROST-READ-RAW-NO-HANG called outside of WITH-BIFROST or FLOKKR form. In order to read from the terminal, BIFROST-READ-RAW-NO-HANG needs to be within one of these forms"))
  (let ((rune (%bifrost-read-raw-no-hang stream)))
    (cond

      ;; nothing there
      ((null rune)
       (setf *rune* nil
             *rune-name*  nil
             *rune-payload* nil)
       nil)

      ;; complex rune
      ((listp rune)
       (setf *rune* rune
             *rune-name* (first rune)
             *rune-payload* (rest rune))
       rune)

      ;; simple rune
      (t
       (setf *rune* rune
             *rune-name* nil
             *rune-payload* nil)
       rune))))

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

(defmacro rune-case (rune &body cases)
  (let ((%rune (gensym "rune"))
        (%rune-name (gensym "rune-name")))
    `(let* ((,%rune ,rune)
            (,%rune-name (if (listp ,%rune)
                             (first ,%rune)
                             ,%rune)))
       (cond
         ,@(mapcar (lambda (clause)
                     (destructuring-bind (key . forms)
                         clause
                       (cond
                         ((eql key 'otherwise)
                          `(t ,@forms))
                         ((null key)
                          `((null ,%rune) ,@forms))
                         ((or (characterp key)
                              (keywordp key))
                          `((eql ,%rune-name ,key) ,@forms))
                         ((listp key)
                          (cond
                            ((or (every #'characterp key)
                                 (every #'keywordp key)    )
                             `((find ,%rune-name ',key) ,@forms))
                            ((keywordp (first key))
                             `((equalp ,%rune-name ,key) ,@forms))
                            (t (error "malformed RUNE-CASE clause ~S" clause))))
                         (t (error "malformed RUNE-CASE clause ~S" clause)))))
                   cases)))))












;;;; sending escape sequences to the terminal


(defvar *bifrost-debug-mode* nil)
  ;; NIL
  ;; :no-control
  ;; :escape-control

(defun %send-escape-sequence (stream &rest strings-and-chars)
  (unless (eq *bifrost-debug-mode* :no-control)
    (dolist (% strings-and-chars)
	    (etypecase   %
	      (string (write-string % stream))
	      (character (if (and (eq *bifrost-debug-mode* :escape-control)
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
  (rune-case (bifrost-read-raw stream)
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

(defun bifrost-write (rune-or-char &optional (stream *bifrost-io*))
  (bifrost-write-raw rune-or-char stream)
  (rune-case rune-or-char
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





;;;; setup: defining CBOX click regions

(defvar *%within-with-cbox-p* nil)
(defvar *cbox-stack*          nil)

(defmacro with-cbox-layer (clear-p &body body)
  (let ((%clear-p (gensym "clear-cbox-context")))
    `(let* ((,%clear-p ,clear-p)
            (*%within-with-cbox-p* t)
            (*cbox-stack* (if ,%clear-p
					                    *cbox-stack*
					                    nil)))
       (declare (special *%within-with-cbox-p*
                         *cbox-stack*))
       ,@body)))

(defstruct cbox
  identifier
  min-row
  min-column
  max-row
  max-column)

(defvar *cbox-min-row*    nil)
(defvar *cbox-min-column* nil)
(defvar *cbox-max-row*    nil)
(defvar *cbox-max-column* nil)

(defun register-cbox! (identifier &key
			                             (min-row *cbox-min-row*) (min-column *cbox-min-column*)
			                             (max-row *cbox-max-row*) (max-column *cbox-max-column*))
  (unless *%within-with-cbox-p*
    (error "REGISTER-CBOX! called outside of WITH-CBOX"))
  (assert (numberp min-row))
  (assert (numberp min-column))
  (assert (numberp max-row))
  (assert (numberp max-column))
  (push (make-cbox :identifier identifier
                   :min-row min-row
                   :min-column min-column
                   :max-row max-row
                   :max-column max-column)
        *cbox-stack*))

(defun lookup-cbox (row column)
  (unless *%within-with-cbox-p*
    (error "LOOKUP-CBOX called outside of WITH-CBOX"))
  (assert (numberp row))
  (assert (numberp column))
  (find-if (lambda (%cbox)
	           (and (cbox-p %cbox)
		              (<= (cbox-min-row %cbox) row)
                  (< row (cbox-max-row %cbox))
		              (<= (cbox-min-column %cbox) column)
                  (< column (cbox-max-column %cbox))))
           *cbox-stack*))





;; pressed buttons, before they are released

(defvar *active-cbox-pressed* nil)

(defun cbox-pressed-p (identifier &key (test #'equalp))
  (unless *%within-with-cbox-p*
    (error "CBOX-PRESSED-P called outside of WITH-CBOX"))
  (and *active-cbox-pressed*
       (funcall test
                identifier
                (cbox-identifier *active-cbox-pressed*))))


;; Reading mouse click / touch screen tap events from the terminal

(defvar *cbox* nil)

(defun bifrost-read-no-hang ()
  (bifrost-read-raw-no-hang)
  (when *rune*
    (case *rune-name*
      (:mouse-click-left
       (destructuring-bind (row column)
           *rune-payload*
         (let ((cbox (lookup-cbox row column)))
           (if cbox
               (setf *cbox*                cbox
                     *active-cbox-pressed* cbox
                     *rune-name*           :cbox-click-left
                     *rune*                (cons *rune-name*
                                                 *rune-payload*))
               (setf *cbox* nil
                     *active-cbox-pressed* nil)))))
      (:mouse-release
       (destructuring-bind (row column)
           *rune-payload*
         (let ((cbox (lookup-cbox row column)))
           (if *active-cbox-pressed*
               (setf *rune-name*
                     (if (eql cbox *active-cbox-pressed*)
                         :cbox-release-left
                         :cbox-unclick-left)
                   
                     *cbox*
                     *active-cbox-pressed*

                     *active-cbox-pressed*
                     nil

                     *rune*
                     (cons *rune-name*
                           *rune-payload*))
               (setf *cbox* nil
                     *active-cbox-pressed* nil)))))
      (otherwise
       (setf *cbox* nil
             *active-cbox-pressed* nil))))
   (values *rune*
           *cbox*))



(defun bifrost-read ()
  (loop (multiple-value-bind (rune cbox)
            (bifrost-read-no-hang)
          (if rune
              (return-from bifrost-read
                (values rune
                        cbox))
              (sleep *bifrost-read-poll-frequency*)))))
