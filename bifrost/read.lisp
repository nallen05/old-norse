

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


;;       (synonym-stream (init-bifrost-io (symbol-value (synonym-stream-symbol sb-sys:*tty*)
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

(defun warn-if-outside-terminal ()
  (unless *bifrost-tty-p*
    (warn "We're outside of a Unix-like terminal emulator. Entering \"read-debug\" mode. To send input to BIFROST, you must force with a newline, similar to READ-LINE, in order to bypass any read buffers in the way of raw IO. See also: *BIFROST-DEBUG-MODE*")
    (finish-output *error-output*)))


;; bifrost read buffer - needed to unread sequences of multiple characters

(defstruct fifo-char-buffer
  first
  last)

(defparameter *rune-read-buffer* (make-fifo-char-buffer))

(defun reset-fifo-char-buffer (&optional (fifo *rune-read-buffer*))
  (setf (fifo-char-buffer-first fifo) nil
        (fifo-char-buffer-last fifo)  nil)
  fifo)

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



;; <<<>>> here
;;   1. [x] export symbol
;;   2. [x] clear output at toplevel
;;   3. [.] debugging mode
;;   4. [ ] update docs


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

(defparameter *rune-read-literal-whitelist*
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
  
;; (defun peek-rune-read-buffer ()
;;   (first (fifo-char-buffer-first *rune-read-buffer*)))

(defparameter *rune-read-debug-literal-char* #\~)

(defun %read-char-burst-no-hang (stream)
  "
like READ-CHAR-NO-HANG except that if multiple characters are buffered to be read from STREAM
then all of them are read & it returns a list of characters instead of a single character

this function should only be called within BIFROST:WITH-BIFROST & sets a special flag
*BIFROST-TTY-P* that indicates whether or not the underlying STREAM is a Unix-like TTY
& TRIVIAl-RAW-IO:WITH-RAW-IO is activated

If we're NOT inside of a Unix-like TTY, then we enter a special read-debug mode that causes
this  function to behaves closer to CL:READ-LINE
  a #\newline -> #\a
  a b c #\newline -> (#\a #\b #\c)

Read-debug mode supports 2 special cases
  1. a single newline is interpreted as #\newline:
     #\newline -> #\newline
  2. the special character *rune-read-debug-literal-char* (which defaults to #\~) allows you to
enter a rune literal
     ~ :up-arrow -> :UP-ARROW
     ~ (:move-cursor 1 1) -> (:MOVE-CURSOR 1 1)
the special character is configurable via *RUNE-READ-DEBUG-LITERAL-CHAR*
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
	        ((eql c1 *rune-read-debug-literal-char*)
	         (let ((bifrost-literal (read stream nil nil)))
	           (unless (or (characterp bifrost-literal)
                         (find (if (listp bifrost-literal)
					                         (first bifrost-literal)
					                         bifrost-literal)
			                         *rune-read-literal-whitelist*))
               (error "Encountered an unknown rune literal ~S. Valid types are ~{~S ~}" bifrost-literal *rune-read-literal-whitelist*))
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
  (if (fifo-char-buffer-first *rune-read-buffer*)
      (pop-fifo-char-buffer *rune-read-buffer*)
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
				                            *rune-read-buffer*)
	         (first burst))))))


;; escape sequences

(defvar *rune-read-alternate-esc-character-for-debugging* nil)

(defvar *rune-read-escape-sequence-max-hang* 0.1)

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
					     *rune-read-buffer*)
		   (return-from ,%block 
		     #\esc))))
	   (declare (special *%abort-escape-sequence-thunk*))
	   ,@body)))))

(defun %get-next-escape-sequence-char (stream)
  (let ((start-time (get-internal-real-time))
	      (timeout-itu-duration (* *rune-read-escape-sequence-max-hang*
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
			                   (prepend-fifo-char-buffer ,c *rune-read-buffer*)
			                   (return 
			                     (let ((,var (read-from-string (coerce (nreverse ,sgr-int-chars)
								                                                 'string))))
			                       ,@body))))))))))))

(defun %rune-read-escape-sequence (stream)
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


(defun %rune-read-raw-no-hang (&optional (stream *bifrost-io*))
  (multiple-value-bind (xx rune-literal-p)
      (%read-char-no-hang stream)
    (cond

      ;; rune literal
      (rune-literal-p
       (if *bifrost-tty-p*
           (error "BIFROST: something is wrong! BIFROST::%RUNE-READ-RAW-NO-HANG encountered a rune literal outside of read-debug mode: ~S" xx)
           xx))
        
      ;; nothing there
      ((null xx)
       nil)
      
      ;; escape sequence
      ((or (eql xx #\esc)
	         (and *rune-read-alternate-esc-character-for-debugging*
		            (eql xx *rune-read-alternate-esc-character-for-debugging*)))
       (%rune-read-escape-sequence stream))
     
      ;; an uninteresting character
      (t
       xx))))

(defvar *rune* nil)
(defvar *rune-name* nil)
(defvar *rune-payload* nil)

(defun rune-read-raw-no-hang (&optional (stream *bifrost-io*))
  (unless *within-with-bifrost-form*
    (error "BIFROST: RUNE-READ-RAW-NO-HANG called outside of WITH-BIFROST or FLOKKR form. In order to read from the terminal, RUNE-READ-RAW-NO-HANG needs to be within one of these forms"))
  (let ((rune (%rune-read-raw-no-hang stream)))
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

(defvar *rune-read-poll-frequency* 0.005)

(defun rune-read-raw (&optional (stream *bifrost-io*))
  (loop
    (let ((rune (rune-read-raw-no-hang stream)))
	    (if rune
	        (return-from rune-read-raw
		        rune)
          (if *bifrost-tty-p*
              (sb-sys:wait-until-fd-usable *bifrost-tty-p* :input)
              (sleep *rune-read-poll-frequency*))))))



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

