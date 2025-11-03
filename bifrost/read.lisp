





(in-package :bifrost)



;; bypass terminal line buffering
;; important setup

(defmacro with-rune-raw-io (&body body)
  (let ((%doit (gensym "with-rune-raw-io-body")))
    `(let ((*%within-bypass-terminal-read-buffer-p* t))
       (declare (special *%within-bypass-terminal-read-buffer-p*))
       (flet ((,%doit () ,@body))
         (if *rune-read-debug-mode*
             (,%doit)
	           (trivial-raw-io:with-raw-io (:vmin 0 :vtime 0)
		           (,%doit)))))))



;; read buffer
;; needed to unread sequences of multiple characters

(defstruct fifo-char-buffer
  first
  last)

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

(defparameter *rune-read-buffer* (make-fifo-char-buffer))

(defvar *rune-read-poll-frequency* 0.005)

(defun flush-rune-read-buffer (&optional (stream *terminal-io*))
  (values (let ((n 0))
	          (loop while (listen stream)
		              do (progn
		                   (read-char stream nil nil)
		                   (incf n)
		                   (sleep *rune-read-poll-frequency*)))
	          n)
	        (let ((n (length (fifo-char-buffer-first *rune-read-buffer*))))
	          (setf *rune-read-buffer* (make-fifo-char-buffer))
	          n)))
  
;; (defun peek-rune-read-buffer ()
;;   (first (fifo-char-buffer-first *rune-read-buffer*)))

(defvar *rune-read-debug-mode* nil)

(defparameter *rune-read-debug-literal-char* #\~)

(defun %read-char-burst-no-hang (stream)
  "
like READ-CHAR-NO-HANG except that if multiple characters are buffered to be read from STREAM
then all of them are read & it returns a list of characters instead of a single character

 in order to bypass line buffering done by most terminals, you need to do one of the following
   A) call within TRIVIAl-RAW-IO:WITH-RAW-IO, or use similar mechanism to bypass at a low-level
   B) set *RUNE-READ-DEBUG-MODE* to T. This switches %READ-CHAR-BURST-NO-HANG into
      a special debugging mode, which functions similarly to READ-LINE.
         a #\newline -> #\a
         a b c #\newline -> (#\a #\b #\c)
      T mode supports 2 special cases
         1. a single newline is interpreted as #\newline:
           #\newline -> #\newline
         2. a special character allows you to enter a rune literal
           ~ :up-arrow -> :UP-ARROW
           ~ (:move-cursor 1 1) -> (:MOVE-CURSOR 1 1)
      in the second case, %READ-CHAR-BURST-NO-HANG also returns a second value: T
      the special character is configurable via *RUNE-READ-DEBUG-LITERAL-CHAR*
      the special character must be the FIRST character of the buffered line to work:
         a b ~ :up-arrow -> (#\a #\b #\~ #\: #\u #\p #\- #\a #\r #\r #\o #\w)
"
  (if *rune-read-debug-mode*

      ;; debugging mode; read the docs to understand
      (let ((c1 (read-char stream nil nil)))
        (cond

          ;; newline, without preceding characters
          ;; treat as a newline
	        ((eql c1 #\newline)
	         #\newline)

          ;; rune literal
	        ((eql c1 *rune-read-debug-literal-char*)
	         (let* ((bifrost-literal (read stream nil nil))
		              (bifrost-literal-type (if (listp bifrost-literal)
					                                  (first bifrost-literal)
					                                  bifrost-literal)))
	           (unless (find bifrost-literal-type
			                     *rune-read-literal-whitelist*)
               (error "BIFROST debug node: encountered rune literal of unknown type ~S. Valid types are ~{~S ~}" bifrost-literal *rune-read-literal-whitelist*))
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
		                   (push cn accum))))))))

      ;; no hang mode
      ;; must be within TRIVIAl-RAW-IO:WITH-RAW-IO to work with terminal
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
                c1))))))

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
	         (if *rune-read-debug-mode*
               (values burst t)
	             (error "BIFROST: something is wrong! Rune literal seen outside of debug mode: ~S" burst)))

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
	        (t (sleep *rune-read-poll-frequency*)))))))

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


(defun %rune-read-raw-no-hang (&optional (stream *terminal-io*))
  (multiple-value-bind (xx rune-literal-p)
      (%read-char-no-hang stream)
    (cond

      ;; rune literal
      (rune-literal-p
       (if *rune-read-debug-mode*
           xx
           (error "BIFROST: something is wrong! Rune literal seen outside of debug mode: ~S" xx)))
        
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

(defun rune-read-raw-no-hang (&optional (stream *terminal-io*))
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
  
(defun rune-read-raw (&optional (stream *terminal-io*))
  (loop
    (let ((rune (rune-read-raw-no-hang stream)))
	    (if rune
	        (return-from rune-read-raw
		        rune)
	        (sleep *rune-read-poll-frequency*)))))



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

