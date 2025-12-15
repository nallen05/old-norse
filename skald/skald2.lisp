




;;;;; INSTRUCTIONS FOR ADDING DOUBLE-WIDTH CHARACTER (EMOJI) SUPPORT
;;
;; DOUBLE-WIDTH-CHAR-P
;;  EMOJI-CHAR-P
;;
;; WRITE-TO-CHANGE-BUFFER + %WRITE-CHAR/UNBOUNDED
;;  => %WRITE-CHAR-LL/UNBOUNDED
;;       * if write (double-width-char-p), then write #\ZERO_WIDTH_SPACE to right
;;         (code-char #x200B) -> #\ZERO_WIDTH_SPACE
;;           except if at right edge of terminal, then write:
;;            change buffer: #\nul
;;            display buffer: fill char
;;       * if write over emoji, then:
;;           change buffer: write #\nul to right
;;           display buffer: write fill char to right
;;       * if write over #\ZERO_WIDTH_SPACE, then:
;;           change buffer: write #\nul to left
;;           display buffer: write fill char to right
;;
;; %WRITE-CHAR
;;  when (double-width-char-p c)
;;    +1 on max x bounds check
;;    +1 on cursor after
;;  even when outside boundingbox
;;
;; EMIT-CHANGE-BUFFER
;;   #\ZERO_WIDTH_SPACE is a no-op (except for updating display buffer)
;;
;; %RENDER-SPAN/ALIGNMENT-PREVIEW
;;   if (double-width-char-p c)
;;      (write-string "XX")
;;      (write-char c)
;;
;; SPRITE/SPAN/etc --> no double-width borders/fillers/etc
;;


(defpackage :skald
  (:use :cl)
  (:export

           ;; initialization & other commands that don't interact with the change buffer
           :skald-init
           :skald-check-terminal-size
           :skald-sync
           :skald-clear
           :*terminal-size*
           :*terminal-size-override* ;; user configurable          
           
           ;; updating the screen via change buffer
           :skald                    ;; :mode=draw,overlay,force-overlay,prep,null
           :*output*
           :*row*
           :*col*

	         ;; writing to the change buffer
           :span
           :sprite

           ;; windows
           :solo-window
           :*window-border*
           :*window-border-chars*
   	       :*window-height*
	         :*window-horizontal-align*
           :*window-width*
           
	         ;; organizing the terminal screen into windows/grids
	         :grid
 	         :column
	         :window
;;	       :row                    ;; not yet implemented

;; making it easier to draw the screen, top down left right
;;         :*extant-min-row*       ;; not yet implemented
;;         :*extant-max-row*       ;; not yet implemented
;;         :*extant-min-col*       ;; not yet implemented
;;         :*extant-max-col*       ;; not yet implemented
;;         :*extant-height*        ;; not yet implemented
;;         :*extant-width*         ;; not yet implemented
           
           ;; defining & referencing colors
	         :def-color
           :lookup-color-code
           :*background-color*
           :*fill-char*
           :*foreground-color*
           :*mask-mode-p*
   	       :*transparant-char*

	         ;; interpolation helpers
           :fixed-step-line

	         ;; emoji
	         :emoji
           :def-emoji
           :lookup-emoji
           :*unrenderable-char-fill-char*
           
           ;; debugging
           :with-skald-test
))



(in-package :skald)



;;;;; vars

;; terminal size

(defvar *terminal-size* '(24 80))   ;; (MAX-ROW MAX-COLUMN)
(defvar *terminal-size-override* nil)

;; buffers
(defvar *%change-buffer* nil)
(defvar *%display-buffer* nil)

;; writing to the change buffer

(defparameter *output*         t)  ;; T -> *TERMINAL-IO*
(defvar       *row*            0)
(defvar       *col*         0)
(defvar       *%within-skald-output* nil)
(defvar       *%within-skald-draw*   nil)

;; ASCII graphics library

(defparameter *foreground-color* :white)
(defparameter *background-color* :black)
(defparameter *fill-char*        #\space)
(defparameter *transparant-char* #\nul)
(defparameter *mask-mode-p*      nil)
(defvar *%color-codes* (make-hash-table))
(defvar *%background-color-code*)
(defvar *%foreground-color-code*)
(defvar *%window-bounding-box-min-row*)
(defvar *%window-bounding-box-min-col*)
(defvar *%window-bounding-box-max-row*)
(defvar *%window-bounding-box-max-col*)
(defvar *%line-start-column*)             ;; for span/sprite :ALIGN
(defvar *%mask-background-color-code*)
(defvar *%mask-foreground-color-code*)

;; emoji as double-width characters

(defvar *unrenderable-char-fill-char*  #\space)
(defvar *%emojis* (make-hash-table))      ;; emoji

;; organizing the terminal screen into windows/grids

(defparameter *window-border*       t)
(defparameter *window-border-chars* "-|+"
  "if provided, should be 3 char string: 0=horizontal 1=vertical 2=intersect
  set to NIL for transparant border; set to NIL for transparant border")

(defparameter *window-height*       5)
(defparameter *window-horizontal-align* :left
  "valid alignments: :left, :right, :center-left, :center-right")

(defparameter *window-width*        10)

(defvar *%plist*)      ;; passed around by SOLO-WINDOW/WINDOW/COLUMN/GRID for inheritence

(defvar *%grid-column-count*)
(defvar *%grid-row-count*)
(defvar *%window-border-background-color-code*)
(defvar *%window-border-foreground-color-code*)
(defvar *%window-column*)  ;; window top-left corner
(defvar *%window-row*)     ;; window top-left corner



;;;; defining colors

(defun def-color (name val)
  (assert (keywordp name))
  (assert (integerp val))
  (setf (gethash name *%color-codes*)
	val))

(defun lookup-color-code (name)
  (unless (keywordp name)
    (error "LOOKUP-COLOR-CODE: malformed color identifier ~S" name))
  (or (gethash name *%color-codes*)
      (error "MINI-AUI: unknown color ~S" name)))
    
(def-color :black 0)
(def-color :red 1)
(def-color :green 2)
(def-color :yellow 3)
(def-color :blue 4)
(def-color :magenta 5)
(def-color :cyan 6)
(def-color :white 7)

(defmacro with-plist (plist &body body) 
  `(let ((*%plist* ,plist))
     (declare (special *%plist*))
     ,@body))

(defmacro with-default-style (&body body)
  `(let ((*%background-color-code* (lookup-color-code *background-color*))
	       (*%foreground-color-code*  (lookup-color-code *foreground-color*)))
     (declare (special *%background-color-code*
		                   *%foreground-color-code*))
     ,@body))

(defmacro with-extend-style (&body body)
  "used by SPAN/SPRITE/SOLO-WINDOW/WINDOW"
  (let ((%bg (gensym "bg-color"))
	      (%fg (gensym "fg-color")))
    `(let* ((*mask-mode-p* (getf *%plist* :mask))
	          (,%bg (getf *%plist* :bg))
	          (*%background-color-code* (if ,%bg
					                                (lookup-color-code ,%bg)
					                                *%background-color-code*))
	          (*%mask-background-color-code* *%background-color-code*)
	          (,%fg (getf *%plist* :fg))
	          (*%foreground-color-code* (if ,%fg
					                                (lookup-color-code ,%fg)
					                                *%foreground-color-code*))
	          (*%mask-foreground-color-code* *%foreground-color-code*))
       (declare (special *mask-mode-p*
			                   *%background-color-code*
			                   *%foreground-color-code*
			                   *%mask-background-color-code*
			                   *%mask-foreground-color-code*))
       ,@body)))

(defun call-in-background (color-name thunk)
  "used by :BG"
  (let ((*%background-color-code* (lookup-color-code color-name)))
    (declare (special *%background-color-code*))
    (funcall thunk)))

(defun call-in-foreground (color-name thunk)
  "used by :FG"
  (let ((*%foreground-color-code* (lookup-color-code color-name)))
    (declare (special *%foreground-color-code*))
    (funcall thunk)))



;;;; defining emojis

(eval-when (:compile-toplevel :load-toplevel :execute)
  (when (ignore-errors
	       (let ((grinning-emoji (code-char #x1F600))  ;; U+1F600 GRINNING FACE
               (neutral-emoji (code-char #x1F610)))  ;; U+1F610 NEUTRAL FACE
           (and (string= (format nil "~A"  grinning-emoji)
		                     (make-string 1 :initial-element grinning-emoji))
                (equalp `(#\a
                          #\b
                          #\c
                          ,grinning-emoji
                          ,neutral-emoji
                          #\d
                          #\e
                          #\f)
                        (coerce (format nil
                                        "abc~c~cdef"
                                        (code-char #x1F600)
                                        (code-char #x1F610))
                                'list)))))
    (pushnew :supports-emojis *features*))
  )

#+supports-emojis
(progn

  (defun def-emoji (name char-code)
    (assert (keywordp name))
    (assert (integerp char-code))
    (assert (<= 0 char-code #x10FFFF))
    (assert (characterp (code-char char-code)))
    (setf (gethash name *%emojis*)
	  char-code))

  (defun lookup-emoji (name)
    (assert (keywordp name))
    (let ((% (gethash name *%emojis*)))
      (if %
	        (code-char %)
	        (error "SKALD: unknown emoji ~S" name))))

  (def-emoji :grinning         #x1F600)
  (def-emoji :grinning-big     #x1F601)
  (def-emoji :tears-of-joy     #x1F602)
  (def-emoji :smiling-open-mouth #x1F603)
  (def-emoji :smiling-eyes     #x1F604)
  (def-emoji :blushing-smile   #x1F60A)
  (def-emoji :winking          #x1F609)
  (def-emoji :heart-eyes       #x1F60D)
  (def-emoji :sunglasses       #x1F60E)
  (def-emoji :thinking         #x1F914)

  (def-emoji :green-check      #x2705)

  (def-emoji :lightning        #x26A1)
  (def-emoji :sparkles         #x2728)

  (def-emoji :money-bag        #x1F4B0)
  (def-emoji :money-mouth      #x1F911)
  (def-emoji :money-wings      #x1F4B8)

  (def-emoji :crossed-swords   #x2694)
  (def-emoji :dagger           #x1F5E1)
)

#-supports-emojis
(progn
  
  (defun def-emoji (name char-code)
    (declare (ignore name char-code))
    (warn "SKALD: implementation does not support emojis"))
  
  (defun lookup-emoji (name)
    (declare (ignore name))
    #\replacement_character)
  )

(defun emoji-p (char)
  (let ((code (char-code char)))
    (or (<= #x1F600 code #x1F64F) ;; Emoticons
        (<= #x1F300 code #x1F5FF) ;; Misc Symbols and Pictographs
        (<= #x1F900 code #x1F9FF) ;; Supplemental Symbols and Pictographs
        (<= #x1F680 code #x1F6FF) ;; Transport and Map
        (<= #x2600 code #x26FF)   ;; Symbols and Arrows
        (<= #x2700 code #x27BF)   ;; Dingbats
        (<= #x1F1E6 code #x1F1FF) ;; Flags
        )))

(defun double-width-character-p (char)
  (emoji-p char)
  ;; could extend...
  )


;;;;; low-level buffer API

;; buffer arrays

(defun %make-buffer-array (&optional initial-element element-type)
  (assert (and (listp *terminal-size*)
               (eql 2 (length *terminal-size*))
               (every #'integerp *terminal-size*)))
  (make-array *terminal-size*
	            :initial-element initial-element
	            :element-type element-type))

(defun %fill-array! (array element)
  (dotimes (i (array-total-size array))
    (setf (row-major-aref array i)
	  element))
  array)

(defun %copy-array! (from to)
  (destructuring-bind (from-max-row from-max-column)
      (array-dimensions from)
    (destructuring-bind (to-max-row to-max-column)
        (array-dimensions to)
      (dotimes (row from-max-row)
        (dotimes (column from-max-column)
          (unless (or (>= row to-max-row)
                      (>= column to-max-column))
            (setf (aref to row column)
                  (aref from row column)))))
      to)))



;; buffers

(defstruct (buffer (:constructor %make-buffer))
  dimensions
  array
  background-color-array
  foreground-color-array
  wiped-p)

(defun make-buffer ()
  (assert (and (listp *terminal-size*)
               (eql 2 (length *terminal-size*))
               (every #'integerp *terminal-size*)))
  (%make-buffer
   :dimensions             *terminal-size*
   :array                  (%make-buffer-array #\nul 'character)
   :background-color-array (%make-buffer-array (lookup-color-code *background-color*)
					                                     '(unsigned-byte 8))
   :foreground-color-array  (%make-buffer-array (lookup-color-code *foreground-color*)
					                                      '(unsigned-byte 8))))

(defun %valid-buffer-p (buffer)
  (assert (and (listp *terminal-size*)
               (eql 2 (length *terminal-size*))
               (every #'integerp *terminal-size*)))
  (and (buffer-p buffer)
       (equal (buffer-dimensions buffer)
	            *terminal-size*)))

(defun %copy-buffer! (from to)
  (assert (buffer-p from))
  (assert (%valid-buffer-p to))
  (if (buffer-wiped-p from)
      (setf (buffer-wiped-p to)
            t)
      (progn
        (%copy-array! (buffer-array from)
		                  (buffer-array to))		
        (%copy-array! (buffer-background-color-array from)
		                  (buffer-background-color-array to))
        (%copy-array! (buffer-foreground-color-array from)
		                  (buffer-foreground-color-array to))
        (setf (buffer-wiped-p to)
              nil)))
  to)

(defun ensure-valid-buffer (buffer)  
  (if (%valid-buffer-p buffer) 
      buffer          
      (if (buffer-p buffer)
          (let ((new-buffer (make-buffer)))
            (%copy-buffer! buffer new-buffer)
            new-buffer)
          (make-buffer))))

(defun clear-buffer! (buffer)
  (%fill-array! (buffer-array buffer)
		            #\nul)
  (%fill-array! (buffer-background-color-array buffer)
		            (lookup-color-code *background-color*))
  (%fill-array! (buffer-foreground-color-array buffer)
		            (lookup-color-code *foreground-color*))
  (setf (buffer-wiped-p buffer)
        nil)
  buffer)

(defun clear-if-wiped! (buffer)
  (when (buffer-wiped-p buffer)
    (clear-buffer! buffer))
  buffer)



;; writing changes in the change buffer to the screen & display buffer

(defmacro with-skald-output (output &body body)
  (let ((%output (gensym "skald-output")))
    `(let* ((,%output ,output)
            (*output* (if (eql ,%output
                                     t)
                                *terminal-io*
                                ,%output))
            (*%within-skald-output* t))
       (declare (special *output*
                         *%within-skald-output*))
       ,@body)))

(defun emit-change-buffer (&optional mode)
  (assert *%within-skald-output*)
  (assert (buffer-p *%change-buffer*))
  (assert (buffer-p *%display-buffer*))
  (assert (and (listp *terminal-size*)
               (eql 2 (length *terminal-size*))
               (every #'integerp *terminal-size*)))
  (assert (find mode '(:draw :overlay :force-overlay)))
  (let* ((default-fg (lookup-color-code *foreground-color*))
         (default-bg (lookup-color-code *background-color*))
         (last-write-fg default-fg)
         (last-write-bg default-bg)
	       last-write-column
	       last-write-row)
    (dotimes (row (first *terminal-size*))
      (dotimes (column (second *terminal-size*))
        (labels ((%access (array)
		               (aref array row column)))
          (let ((c (%access (buffer-array *%change-buffer*)))
                (fg (%access (buffer-foreground-color-array *%change-buffer*)))
                (bg (%access (buffer-background-color-array *%change-buffer*))))
            (flet ((%different-color-p ()
                     (or (not (= bg (%access (buffer-background-color-array *%display-buffer*))))
			                   (not (= fg (%access (buffer-foreground-color-array *%display-buffer*)))))))
              (when (if (eql c #\nul)
                        (when (eql mode :draw)
                          (let ((dc (%access (buffer-array *%display-buffer*))))
                            (or (and (not (eql dc #\nul))
                                     (not (eql dc *fill-char*)))
                                (%different-color-p))))
                        (or (eql mode :force-overlay)
                            (not (char= c (%access (buffer-array *%display-buffer*))))
                            (%different-color-p)))

                ;; #\ZERO_WIDTH_SPACE indicates the obstructed character next to
                ;; a double width character, such as an emoji. encountering one
                ;; should never trigger updating the style or position
                (unless (eql c #\zero_width_space)
                  
	                ;; if necessary, change bg/fg color before continuing
	                (unless (eq bifrost:*bifrost-debug-mode*
                              :human-readable)
		                (unless (= bg last-write-bg)
                      (bifrost:rune-write `(:background ,bg)
                                          *output*)
		                  (setf last-write-bg bg))
		                (unless (= fg last-write-fg)
                      (bifrost:rune-write `(:foreground ,fg)
                                          *output*)
		                  (setf last-write-fg fg)))
                  
	                ;; if necessary, reposition the cursor before continuing
	                (unless (and last-write-row
			                         (= row last-write-row)
			                         last-write-column
			                         (= column (1+ last-write-column)))
		                (if (eq bifrost:*bifrost-debug-mode*
                            :human-readable)
		                    (when (and last-write-row
			                             last-write-column)
		                      (if (and (= row last-write-row)
			                             (> column (1+ last-write-column)))
			                        (write-string (make-string (- column (1+ last-write-column))
						                                             :initial-element #\space)
					                                  *output*)
			                        (write-char #\newline
				                                  *output*)))
                        (bifrost:rune-write `(:move-cursor ,row ,column)
                                            *output*)))
                  )
                  
		            ;; write the char
		            (write-char (case c
                              (#\nul *fill-char*)
                              (#\replacement_character *unrenderable-char-fill-char*)
                              (otherwise c))
                            *output*)
		            (setf last-write-row row
		                  last-write-column column)

		            ;; if in an overlay mode, update the display buffer to reflect
                (when (or (eql mode :overlay)
                          (eql mode :force-overlay))
		              (setf (aref (buffer-array *%display-buffer*) row column)
			                  c
			                      
			                  (aref (buffer-background-color-array *%display-buffer*) row column)
			                  bg
			                  
			                  (aref (buffer-foreground-color-array *%display-buffer*) row column)
			                  fg))))))))

    ;; at the end, if the color has changed, put it back in the default color in order to
    ;; to minimize chance of artifacts
    (unless (eql last-write-fg default-fg)
      (bifrost:rune-write `(:foreground ,default-fg)
                          *output*))
    (unless (eql last-write-bg default-bg)
	    (bifrost:rune-write `(:background ,default-bg)
                          *output*))))


;;;; debugging mode

(defun call-in-skald-test (thunk &rest plist)
  (let ((output (getf plist :output t)))
    (if (null output)
        (with-output-to-string (s)
          (apply #'call-in-skald-test
                 thunk
                 :output s
                 plist))
        (let ((bifrost:*bifrost-debug-mode* (getf plist
                                                     :debug-mode
                                                     bifrost:*bifrost-debug-mode*))
              (*terminal-size-override* (getf plist
                                                    :override-terminal-size
                                                    *terminal-size-override*)))
          (declare (special bifrost:*bifrost-debug-mode*
                            *terminal-size-override*))
          (with-skald-output output
            (funcall thunk))))))

(defmacro with-skald-test ((&rest kwd-args &key debug-mode output override-terminal-size) &body body)
  (declare (ignore debug-mode output override-terminal-size))
  `(call-in-skald-test (lambda ()
                         "WITH-SKALD-DEBUG thunk"
                         ,@body)
                       ,@kwd-args))



;;;; main user API

(defun skald-check-terminal-size ()
  (let ((new-size (or *terminal-size-override*
                      (if bifrost:*bifrost-debug-mode*
                          (error "SKALD-CHECK-TERMINAL-SIZE called in debugging mode ~S without manually overriding the terminakl size. It won't work because it can't communicate with the terminal in this debugging mode. Set *TERMINAL-SIZE-OVERRIDE*"
                                 bifrost:*bifrost-debug-mode*))
                      (with-skald-output *output*
                        (rest (bifrost:rune-write :query-terminal-size
                                                  *output*))))))

    ;; double check it's a valid size, then set
    (assert (and (listp new-size)
                 (eql 2 (length new-size))
                 (every #'integerp new-size)))

    ;; if it has changed, return the new size
    ;; otherwise return NIL
    (unless (equalp new-size
                    *terminal-size*)
      (setf *terminal-size*
            new-size))))

(defun %wipe-buffers! ()
  (when *%change-buffer*
    (setf (buffer-wiped-p *%change-buffer*)
          t))
  (when *%display-buffer*
    (setf (buffer-wiped-p *%display-buffer*)
          t)))

(defun skald-init ()
  (with-skald-output *output*
    (skald-check-terminal-size)
    (bifrost:rune-write :reset
                        *output*)
    ;; set the color before clearing, otherwise the background may
    ;; be a random color
    (with-default-style
      (bifrost:rune-write `(:background ,*%background-color-code*)
                          *output*)
	    (bifrost:rune-write `(:foreground  ,*%foreground-color-code*)
                          *output*))
    (bifrost:rune-write :clear
                        *output*)
    (bifrost:rune-write :hide-cursor
                        *output*)
    (%wipe-buffers!)
    (finish-output *output*)
    (values)))

(defun skald-clear ()
  (with-skald-output *output*
    (bifrost:rune-write :clear
                        *output*)
    (%wipe-buffers!)
    (finish-output *output*)
    (values)))

(defun skald-sync ()
  (assert (and (listp *terminal-size*)
               (eql 2 (length *terminal-size*))
               (every #'integerp *terminal-size*)))

  ;; change buffer
  (setf *%change-buffer*
        (ensure-valid-buffer *%change-buffer*))
  (clear-if-wiped! *%change-buffer*)

  ;; display buffer
  (setf *%display-buffer*
        (ensure-valid-buffer *%display-buffer*))
  (clear-if-wiped! *%display-buffer*))

(defun call-in-skald-draw (mode thunk)
  (assert (find mode '(:draw :overlay :force-overlay :prep :null)))

  ;; make sure the buffers are the correct size & clean
  (skald-sync)
  
  ;; setup output stream & style
  (with-skald-output *output*
    (with-default-style

      ;; write to the change buffer
      (let ((*%within-skald-draw* t))
        (declare (special *%within-skald-draw*))
        (funcall thunk))

      ;; maybe propogate changes to the screen & display buffer
      (ecase mode
        ((:null :prep) nil)
        ((:draw :overlay :force-overlay)
         (emit-change-buffer mode)
         (when (eq bifrost:*bifrost-debug-mode*
                   :human-readable)
	         (write-char #\newline
                       *output*))))

      ;; maybe rotate & wipe the change buffer
      (ecase mode
        (:prep nil)
        ((:draw :overlay :force-overlay :null)
         (when (eql mode :draw)
           (rotatef *%change-buffer*
                    *%display-buffer*))
         (setf (buffer-wiped-p *%change-buffer*)
               t)))

      ;; finish output
      (finish-output *output*)
      (values))))

(defmacro skald ((&optional (mode :draw)) &body body)
  `(call-in-skald-draw ,mode
                       (lambda ()
                         "SKALD-DRAW thunk"
                         ,@body)))


;;;; forms used within SKALD

;; setup: transparant & fill char

(defmacro with-transparant-and-fill-char (&body body)
  `(let ((*transparant-char* (getf plist :transparant-char *transparant-char*))
	       (*fill-char* (getf plist :fill-char *fill-char*)))
     (declare (special *transparant-char*
		                   *fill-char*))   
     ,@body))


;; setup: bounding box for windows
;; used for trimming & left/right fill
(defmacro with-window-bounding-box (row height column width &body body)
  (let ((%height (gensym "height"))
	      (%width (gensym "width")))
    `(let* ((*%window-bounding-box-min-row* ,row)
	          (,%height ,height)
	          (*%window-bounding-box-max-row* (when (and *%window-bounding-box-min-row* ,%height)
				                                      (+ *%window-bounding-box-min-row* ,%height)))
	          (*%window-bounding-box-min-col* ,column)
	          (,%width ,width)
	          (*%window-bounding-box-max-col* (when (and *%window-bounding-box-min-col* ,%width)
				                                         (+ *%window-bounding-box-min-col* ,%width))))
       (declare (special *%window-bounding-box-min-row*
			                   *%window-bounding-box-max-row*
			                   *%window-bounding-box-min-col*
			                   *%window-bounding-box-max-col*))
       ,@body)))


;; write to change buffer respecting bounding boxes & transparant/fill chars

(defun outside-terminal-dimensions-p (&key (row *row*)
                                           (column *col*))
  (assert (and (listp *terminal-size*)
               (eql 2 (length *terminal-size*))
               (every #'integerp *terminal-size*)))
  (destructuring-bind (max-row max-column)
      *terminal-size*
    (or (< row 1)
        (>= row max-row)
        (< column 1)
        (>= column max-column))))

(defun outside-window-bounding-box-p (&key (row *row*)
                                           (column *col*))
  (assert (boundp '*%window-bounding-box-min-col*))
  (assert (boundp '*%window-bounding-box-max-col*))
  (assert (boundp '*%window-bounding-box-min-row*))
  (assert (boundp '*%window-bounding-box-max-row*))
  (or (and *%window-bounding-box-min-row*
	         (< row *%window-bounding-box-min-row*))		 
      (and *%window-bounding-box-max-row*
	         (>= row *%window-bounding-box-max-row*))
      (and *%window-bounding-box-min-col*
	         (< column *%window-bounding-box-min-col*))
      (and *%window-bounding-box-max-col*
	         (>= column *%window-bounding-box-max-col*))))


#|

;;;; SPECIFICATION: EMOJIS AS DOUBLE WIDTH CHARACTERS

;; notes
- emojis are treated as double width characters
- double width characters only take up 1 char space in the read/change buffers,
  but they should always be followed by #\ZERO_WIDTH_SPACE
- #\ZERO_WIDTH_SPACE should otherwise never be written to a buffer
- when a double width character is destructively chopped (eg: a window being written
  on top of it or a window bounding box), then #\REPLACEMENT_CHARACTER is left behind
- when EMIT-CHANGE-BUFFER encounters #\REPLACEMENT_CHARACTER, it writes
  *UNRENDERABLE-CHAR-FILL-CHAR*, which defaults to #\SPACE
- don't use double width characters as fill characters...

;; here is a key explaining how to read the specified cases below
  a b c d        sequence of characters in buffer
  A+z c d        this sequence starts with double width char A followed by #\ZERO_WIDTH_CHAR
  ? b c d        this sequence starts #\REPLACEMENT-CHAR
 {a b}c d        there is a window bounding box around characters a & b, but not c & d


;; updating buffer to insert single width char "x" at position 2
;; potential conflict with bounding box edges
;; unless no op, incf *COL* by 1
{a b c d}   >   a x c d    ;; boring insert
 a{b c d}   >   a x c d    ;; boring insert
 a b{c d}                  ;; no op
 a b c{d}                  ;; no op
 a{b c}d    >   a x c d    ;; boring insert
{a b}c d    >   a x c d    ;; boring insert

;; updating buffer to insert double width char "X+z" at position 2
;; potential conflict with bounding box edges
;; unless no op, incf *COL* by 2
{a b c d}   >   a X+z d    ;; boring insert
 a{b c d}   >   a X+z d    ;; boring insert
 a b{c d}                  ;; no op
 a b c{d}                  ;; no op
 a{b c}d    >   a X+z d    ;; boring insert
{a b}c d    >   a ? c d    ;; can't write double width char; inserting artifact

;; updating buffer to insert single width char "x" at position 2
;; potential conflict with double width char already in buffer
;; always incf *COL* by 1
a b c d   >   a x c d    ;; boring insert
A+z c d   >   ? x c d    ;; A+z chopped! leaving artifact
a B+z d   >   a x ? d    ;; B+z chopped! leaving artifact
a b C+z   >   a x X+z    ;; boring insert


;; updating buffer to insert double width char "X+z" at position 2
;; potential conflict with other double width char in buffer
;; always incf *COL* by 2
a b c d   >   a X+z d    ;; boring insert
A+z c d   >   ? X+z d    ;; A+z chopped! leaving artifact
a B+z d   >   a X+z d    ;; boring insert
a b C+z   >   a X+z ?    ;; C+z chopped! leaving artifact


;; updating buffer to insert single width char "x" at position 2
;; potential conflict with BOTH doublel width char & bounding box edges
;; unless no op, incf *COL* by 1
 A+{z  c  d}   >   ? x c d   ;; A+z chopped! leaving artifact
 a {B++z  d}   >   a x ? d   ;; B+z chopped! leaving artifact
 A++z {c  d}                 ;; no op
 a  B+{z  d}                 ;; no op
 a  B++z {d}                 ;; no op
 a {B++z} d    >   a x ? d   ;; B+z chopped! leaving artifact
{a  B}+z  d    >   a x ? d   ;; B+z chopped! leaving artifact
{A++z} c  d    >   ? x c d   ;; A+z chopped! leaving artifact


;; updating buffer to insert double width char "X+z" at position 2
;; potential conflict with BOTH double width char & bounding box edges
;; unless no op, incf *COL* by 2
 A+{z  c  d}   >   ? X+z d   ;; A+z chopped! leaving artifact
 a {B++z  d}   >   a X+z d   ;; boring insert
 A++z {c  d}                 ;; no op
 a  B+{z  d}                 ;; no op
 a  B++z {d}   >   a X+z d   ;; no op
 a {B++z} d    >   a X+z d   ;; boring insert
{a  B}+z  d    >   a ? ? d   ;; max artifacts! chaos!
{A++z} c  d    >   ? ? c d   ;; max artifacts! chaos!
|#


(defun %%write-single-width-character-to-change-buffer-low-level (c ignore-preceding ignore-following)
  "
Writes to the change buffer
- Blindly does it without checking anything but *MASK-MODE-P*
- Does NOT update *COL* or CBOX
- IGNORE-PRECEDING & IGNORE-FOLLOWING can be used to supress cleanup of chopped double width chars
"
  (setf ;; bg
        (aref (buffer-background-color-array *%change-buffer*)
              *row*
              *col*)
	      (if *mask-mode-p*
	          *%mask-background-color-code*
	          *%background-color-code*)

        ;; fg
	      (aref (buffer-foreground-color-array *%change-buffer*)
              *row*
              *col*)
	      (if *mask-mode-p*
	          *%mask-foreground-color-code*
	          *%foreground-color-code*)

        ;; char
	      (aref (buffer-array *%change-buffer*)
              *row*
              *col*)
	      (if *mask-mode-p*
	          *fill-char*
	          c))

  ;; if this single width character chopped a double width character,
  ;; then insert artifacts
  (unless (or ignore-preceding
              (outside-terminal-dimensions-p :column (1- *col*)))
    (when (double-width-character-p (aref (buffer-array *%change-buffer*)
                                          *row*
                                          (1- *col*)))
      (setf (aref (buffer-array *%change-buffer*)
                  *row*
                  (1- *col*))
            #\replacement_character)))
  (unless (or ignore-following
              (outside-terminal-dimensions-p :column (1+ *col*)))
    (when (eql (aref (buffer-array *%change-buffer*)
                     *row*
                     (1+ *col*))
               #\zero_width_space)
      (setf (aref (buffer-array *%change-buffer*)
                  *row*
                  (1+ *col*))
            #\replacement_character))))

(defun %write-single-width-character-to-change-buffer (c ignore-window-bounding-box)
  (unless (or (outside-terminal-dimensions-p)
              (and (not ignore-window-bounding-box)
                   (outside-window-bounding-box-p)))
    (unless (char= c *transparant-char*)
      (%%write-single-width-character-to-change-buffer-low-level c nil nil)))
  (incf *col*))

;; <<<>> THIS IS WHERE THE EMOJI BUG IS
;;    look at how %%WRITE-SINGLE-WIDTH.... is called

(defun %write-double-width-character-to-change-buffer (c)
  (if (or (outside-terminal-dimensions-p)
          (outside-window-bounding-box-p))
      (incf *col*
            2)
      (if (or (outside-terminal-dimensions-p :column (1+ *col*))
              (outside-window-bounding-box-p :column (1+ *col*)))

          ;; not enough room to fit a double width character,
          ;; write an artifact instead
          (progn
            (unless (char= c *transparant-char*)
              (%%write-single-width-character-to-change-buffer-low-level #\replacement_character
                                                                         nil
                                                                         nil))
            (incf *col*
                  2))

          ;; insert the double width character & also a #\ZERO_WIDTH_SPACE after it
          (progn
            (unless (char= c *transparant-char*)
              (%%write-single-width-character-to-change-buffer-low-level c
                                                                         nil
                                                                         t))
            (incf *col*)
            (unless (char= c *transparant-char*)
              (%%write-single-width-character-to-change-buffer-low-level #\zero_width_space
                                                                         t
                                                                         nil))
            (incf *col*)))))


(defun write-to-change-buffer (c &optional ignore-window-bounding-box)
  (assert *%within-skald-output*)
  (assert (numberp *row*))
  (assert (numberp *col*))
  (cond
    ((eql c #\zero_width_space)
     nil)
    ((double-width-character-p c)
     (when ignore-window-bounding-box
       (error "WRITE-TO-CHANGE-BUFFER: double width characters shouldn't be written outside of a bounding box: ~S" c))
     (%write-double-width-character-to-change-buffer c))
    (t
     (%write-single-width-character-to-change-buffer c ignore-window-bounding-box)))
  c)




;; (defun write-to-change-buffer (c &optional ignore-window-bounding-box)
;;   (assert *%within-skald-output*)
;;   (assert (numberp *row*))
;;   (assert (numberp *col*))
;;   (unless (and (outside-window-bounding-box-p)
;;                (not ignore-window-bounding-box))
;;     (unless (or (outside-terminal-dimensions-p)              
;;                 (char= c *transparant-char*))   
;;       (setf ;; bg
;;             (aref (buffer-background-color-array *%change-buffer*)
;;              *row*
;;              *col*)
;; 	          (if *mask-mode-p*
;; 	              *%mask-background-color-code*
;; 	              *%background-color-code*)

;;             ;; fg
;; 	          (aref (buffer-foreground-color-array *%change-buffer*)
;;                   *row*
;;                   *col*)
;; 	          (if *mask-mode-p*
;; 	              *%mask-foreground-color-code*
;; 	              *%foreground-color-code*)

;;             ;; char
;; 	          (aref (buffer-array *%change-buffer*)
;;                   *row*
;;                   *col*)
;; 	          (if *mask-mode-p*
;; 	              *fill-char*
;; 	              c)))
;;     (update-cbox-bounding-box!))  
;;   (incf *col*)
;;   c)






;; spans of ASCII text (all on the same line)

(defun %render-span (form)
  (assert *row*)
  (assert *col*)
  (etypecase form
    (null nil)
    (symbol (if (eql form
		                 :nodisplay)
		            nil
		            (error "SKALD: invalid span form ~S" form)))
    (character
     (unless (or (char= form #\newline)
		             (char= form #\return))
       (write-to-change-buffer form)))
    (string (map nil
		             #'%render-span
		             form))
    (list (destructuring-bind (1st . rest)
	            form
	          (ecase 1st
	            (:nodisplay nil)
	            (:span (map nil #'%render-span rest))
	            (:sprite (error "SKALD: SPRITE can't be within a SPAN"))
	            (:emoji (%render-span (lookup-emoji (first rest))))
	            (:fg
		              (call-in-foreground (first rest)
				                              (lambda ()
				                                (map nil
					                                   #'%render-span
					                                   (rest rest)))))
	            (:bg
		              (call-in-background (first rest)
				                              (lambda ()
					                              (map nil
					                                   #'%render-span
					                                   (rest rest))))))))))

(defun %render-span/alignment-preview (form)
  (etypecase form
    (null nil)
    (symbol (if (eql form
		                 :nodisplay)
		            nil
		            (error "SKALD: invalid span form ~S" form)))
    (character
     (unless (or (char= form #\newline)
		             (char= form #\return)
		             (char= form *transparant-char*))
       (write-char form *output*)))
    (string (map nil
		             #'%render-span/alignment-preview
		             form))
    (list (destructuring-bind (1st . rest)
	            form
	          (ecase 1st
	            (:span (map nil #'%render-span/alignment-preview rest))
	            (:sprite (error "SKALD: SPRITE can't be within a SPAN"))
    	        ((:fg :bg)
	             (map nil #'%render-span/alignment-preview (rest rest))))))))

(defun %chop-string-by-newline (str &optional (start 0) accum)
  (let ((pos (position-if (lambda (c)
			                      (or (char= c #\newline)
				                        (char= c #\return)))
			                    str
			                    :start start)))
    (if pos
	      (%chop-string-by-newline str
				                         (1+ pos)
				                         (cons (subseq str start pos)
				                               accum))
	      (if (zerop start)
	          (list str)
	          (nreverse (cons (subseq str start)
			                      accum))))))

(defmacro with-align (&body body)
  `(let ((*window-horizontal-align* (getf *%plist* :align *window-horizontal-align*)))
     (declare (special *window-horizontal-align*))
     ,@body))

(defmacro with-line-start (column &body body)
  `(let ((*%line-start-column* ,column))
     (declare (special *%line-start-column*))
     ,@body))


(defmacro with-adjusted-line-start/simple (column width &body body)
  (let ((%column (gensym "column"))
	      (%width (gensym "width")))
    `(let ((,%column ,column)
	         (,%width ,width))
       (with-line-start (ecase *window-horizontal-align*
			                    (:left ,%column)
			                    (:center-left (+ (- ,%column (ceiling (/ ,%width 2)))
					                                 (if (oddp ,%width)
					                                     0
					                                     0)))
			                    (:center-right (+ (- ,%column (floor (/ ,%width 2)))
					                                  (if (oddp ,%width)
						                                    -1
						                                    1)))
			                    (:right (1+ (- ,%column ,%width))))
	       ,@body))))

(defun span* (row column plist &rest subsegments)
  (unless *%within-skald-draw*
    (error "SPAN called outside of SKALD: ~S ~S ~S" row column subsegments))
  (with-plist plist
    (with-extend-style
      (with-transparant-and-fill-char
	      (with-window-bounding-box nil nil nil nil
	        (with-align
	          (ecase *window-horizontal-align*
	            (:left
	             (with-line-start column
                 (setf *row* row
                       *col* column)
		             (map nil #'%render-span subsegments)))
	            ((:right :center-left :center-right)
	             (let* ((preview (with-output-to-string (*output*)
				                         (declare (special *output*))
				                         (map nil #'%render-sprite/alignment-preview subsegments)))
		                  (span-length (apply #'max
					                                (mapcar #'length
						                                      (skald::%chop-string-by-newline preview)))))
		             (with-adjusted-line-start/simple column span-length
                   (setf *row* row
                         *col* *%line-start-column*)
		               (map nil #'%render-span subsegments)))))
	          (values)))))))

(defmacro span ((row column
		             &rest kwd-args
		             &key align bg fg mask fill-char transparant-char)
		            &body subsegments) 
  (declare (ignore align bg fg mask fill-char transparant-char))
  `(span* ,row
	        ,column
	        (list ,@kwd-args)
	        ,@subsegments))


;; ASCII sprites (multi-line)

(defun %begin-sprite-line ()
  (assert (boundp '*%window-bounding-box-min-col*))
  (assert (characterp *fill-char*))
  (assert (integerp *%line-start-column*))
  (assert (integerp *row*))

  ;; move to the sprite's starting column
  (setf *col* *%line-start-column*)

  ;; if we're to the right of the bounding box
  ;; add left fill until we reach it
  (when (and *%window-bounding-box-min-col*
	           (> *col* *%window-bounding-box-min-col*)
	           (not (eql *fill-char*
		                   *transparant-char*)))
    (let ((filler-length (- *col* *%window-bounding-box-min-col*)))
      (setf *col* *%window-bounding-box-min-col*)
      (dotimes (% filler-length)
	      (write-to-change-buffer *fill-char*)))))

(defun %finish-sprite-line ()
  (assert (boundp '*%window-bounding-box-min-col*))
  (assert (boundp '*%window-bounding-box-max-col*))
  (assert (characterp *fill-char*))
  (assert (integerp *%line-start-column*))
  (assert (integerp *col*))
  (assert (integerp *row*))

  ;; if we're in a window & the line ended to the left of the window right bounds
  ;; then add right fill
  (when (and *%window-bounding-box-max-col*
	           (< *col* *%window-bounding-box-max-col*)
	           (not (eql *fill-char*
		                   *transparant-char*)))

    ;; but of course, don't write to the left of the window left bounds
    ;; in the off chance the line ended before reaching the visible part of the bounding box
    (when (and *%window-bounding-box-min-col*
	             (< *col* *%window-bounding-box-min-col*))
      (setf *col* *%window-bounding-box-min-col*))
    (let ((filler-length (- *%window-bounding-box-max-col* *col*)))
      (dotimes (% filler-length)
	      (write-to-change-buffer *fill-char*))))
  (incf *row*)
  (setf *col* *%line-start-column*))

(defun %render-sprite (xx)
  (assert (integerp *col*))
  (assert (integerp *row*))
  (flet ((%maybe-write-char (c)
	         (cond
	           ((or (char= c #\newline)
		              (char= c #\return))
	            (%finish-sprite-line)
	            (%begin-sprite-line))
	           (t (write-to-change-buffer c)))))
    (etypecase xx
      (null
       (%begin-sprite-line)
       (%finish-sprite-line))
      (character
       (%begin-sprite-line)
       (%maybe-write-char xx)
       (%finish-sprite-line))
      (string
       (%begin-sprite-line)
       (map nil
	          #'%maybe-write-char
	          xx)
       (%finish-sprite-line))
      (symbol (if (eql xx
		                   :nodisplay)
		              nil
		              (error "SKALD: invalid sprite form ~S" xx)))
      (list (destructuring-bind (1st . rest)
		            xx
	            (ecase 1st
		            (:nodisplay nil)
		            (:span
		                (%begin-sprite-line)
		              (map nil #'%render-span rest)
		              (%finish-sprite-line))
		            (:sprite (map nil #'%render-sprite rest))
		            (:emoji (%render-sprite (lookup-emoji (first rest))))
		            (:fg
		                (call-in-foreground (first rest)
				                                (lambda ()
					                                (map nil #'%render-sprite
					                                     (rest rest)))))
		            (:bg
		                (call-in-background (first rest)
					                              (lambda ()
					                                (map nil #'%render-sprite
					                                     (rest rest)))))))))))

(defun %render-sprite/alignment-preview (form)
  (flet ((%nl ()
	         (write-char #\newline *output*)))
    (etypecase form
      (null (%nl))
      (symbol
       (if (eql form
		            :nodisplay)
	         nil
	         (error "SKALD: invalid span form ~S" form)))
      (character
       (unless (char= form *transparant-char*)
	       (%nl)
	       (write-char form *output*)))
      (string
       (%nl)
       (map nil
	          (lambda (c)
	            (unless (char= c *transparant-char*)
		            (write-char c *output*)))
	          form))
      (list (destructuring-bind (1st . rest)
		            form
	            (ecase 1st
		            (:nodisplay)
		             nil)
		            (:span
		                (%nl)
		              (map nil #'%render-span/alignment-preview rest))
		            (:sprite
		                (map nil #'%render-sprite/alignment-preview rest))
		            (:emoji (%render-sprite/alignment-preview (lookup-emoji (first rest))))
    		        ((:fg :bg)
		             (map nil #'%render-sprite/alignment-preview (rest rest)))))))))

(defun sprite* (row column plist &rest sprites)
  (unless *%within-skald-draw*
    (error "SPRITE called outside of SKALD: ~S ~S ~S" row column sprites))
  (with-plist plist
    (with-extend-style
      (with-transparant-and-fill-char
	      (with-window-bounding-box nil nil nil nil
	        (with-align
	          (ecase *window-horizontal-align*
	            (:left
	             (with-line-start column
                 (setf *row* row
                       *col* column)
		             (map nil #'%render-sprite sprites)))
	            ((:right :center-left :center-right)
	             (let* ((preview (with-output-to-string (*output*)
				                         (declare (special *output*))
				                         (map nil #'%render-sprite/alignment-preview sprites)))
		                  (span-length (apply #'max
					                                (mapcar #'length
						                                      (%chop-string-by-newline preview)))))
		             (with-adjusted-line-start/simple column span-length
                   (setf *row* row
                         *col* *%line-start-column*)
		               (map nil #'%render-sprite sprites)))))
	          (values)))))))

(defmacro sprite ((row column
		               &rest kwd-args
		               &key align bg fg mask fill-char transparant-char)
		              &body subsegments)
  (declare (ignore align fg bg mask fill-char transparant-char))
  `(sprite* ,row
	          ,column
	          (list ,@kwd-args)
	          ,@subsegments))


;; organizing the screen into windows/grids

(defmacro with-window-grid (row column &body body)
  (let ((%bg (gensym "background-color-name"))
	      (%fg (gensym "foreground-color-name")))
    `(let ((*%grid-row-count* 0)
 	         (*%grid-column-count* 0)
	         (*%window-row* ,row)
 	         (*%window-column* ,column)
	         (*window-border* (getf *%plist* :border *window-border*))
	         (*window-border-chars* (getf *%plist* :border-chars *window-border-chars*))  ;; 0=horizontal 1=vertical 2=intersect
	         (,%bg (getf *%plist* :border-bg))
	         (,%fg (getf *%plist* :border-fg)))
       (declare (special *%grid-row-count*
 			                   *%grid-column-count*
			                   *%window-row*
			                   *%window-column*
			                   *window-border*
			                   *window-border-chars*))
       (let ((*%window-border-background-color-code* (if ,%bg
							                                           (lookup-color-code ,%bg)
							                                           *%background-color-code*))
	           (*%window-border-foreground-color-code* (if ,%fg
							                                           (lookup-color-code ,%fg)
							                                           *%foreground-color-code*)))
	       (declare (special *%window-border-background-color-code*
			                     *%window-border-foreground-color-code*))
	       ,@body))))

(defmacro with-window-grid-column (&body body)
  `(let ((*window-width* (getf *%plist* :width *window-width*))
	       (*%grid-row-count* 0)       ;; resets to 0 with each column
	       (*%window-row* *%window-row*))  ;; resets to what was set by WITH-WINDOW-GRID
     (declare (special *window-width*
		                   *%grid-row-count*
		                   *%window-row*))
     ,@body))

(defmacro with-adjusted-line-start/window (sprite-width &body body)
  (let ((%sprite-width (gensym "width")))
    `(let ((,%sprite-width ,sprite-width))
       (assert (keywordp *window-horizontal-align*))
       (assert (integerp *window-width*))
       (assert (integerp *%window-bounding-box-min-col*))
       (with-line-start (cond

			                    ;; the sprite is exactly the correct length
			                    ((= ,%sprite-width *window-width*)
			                     *%window-bounding-box-min-col*)

			                    ;; the sprite is narrower than the window
			                    ;; so move it to the right to align
			                    ((< ,%sprite-width
			                        *window-width*)
			                     (+ *%window-bounding-box-min-col*
			                        (let ((% (- *window-width*
					                                ,%sprite-width)))
		       		                  (ecase *window-horizontal-align*
				                          (:right %)
				                          (:center-left (floor (/ % 2)))							  
				                          (:center-right (ceiling (/ % 2)))))))

			                    ;; the sprite is wider than the window
			                    ;; so move it to the left to align
			                    ((> ,%sprite-width
			                        *window-width*)
			                     (- *%window-bounding-box-min-col*
			                        (let ((% (- ,%sprite-width
					                                *window-width*)))
				                        (ecase *window-horizontal-align*
				                          (:right %)
				                          (:center-left (ceiling (/ % 2)))
				                          (:center-right (floor (/ % 2))))))))
	       ,@body))))

(defmacro with-window (&body body)
  (let ((%doit (gensym "window-body")))
    `(let ((*window-height* (getf *%plist* :height *window-height*)))
       (declare (special *window-height*))
       (flet ((,%doit ()
		            ,@body))
	       (with-extend-style
	         (with-transparant-and-fill-char
	           (with-window-bounding-box (+ *%window-row*
				                                  (if *window-border*
				                                      1
				                                      0))
				         *window-height*
				         (+ *%window-column*
				            (if *window-border*
				                1
				                0))
				         *window-width*
	             (with-align
		             (ecase *window-horizontal-align*
		               (:left
		                (with-line-start *%window-bounding-box-min-col*
                      (setf *row* *%window-bounding-box-min-row*
                            *col* *%line-start-column*)
			                (,%doit)))
		               ((:right :center-left :center-right)
		                (let* ((preview (with-output-to-string (*output*)
				                              (declare (special *output*))
				                              (map nil #'%render-sprite/alignment-preview sprites)))
			                     (longest-line (apply #'max
						                                    (mapcar #'length
							                                          (%chop-string-by-newline preview)))))
		                  (with-adjusted-line-start/window longest-line
                        (setf *row* *%window-bounding-box-min-row*
                              *col* *%line-start-column*)
			                  (,%doit)))))))))))))

(defun %maybe-append-blank-lines ()
  (assert (boundp '*%window-bounding-box-max-row*))
  (assert (boundp '*%window-bounding-box-min-col*))
  (assert (characterp *fill-char*))
  (assert (integerp *row*))
  (when (and *%window-bounding-box-max-row*
	           (< *row*
                *%window-bounding-box-max-row*))
    (loop until (>= *row*
                    *%window-bounding-box-max-row*)
	        do (%begin-sprite-line)
	           (%finish-sprite-line))))

(defun %maybe-render-window-ascii-border ()
  (assert (boundp '*window-border-chars*))
  (assert (boundp '*%window-border-foreground-color-code*))
  (assert (boundp '*%window-border-background-color-code*))
  (assert *%grid-column-count*)
  (assert *%grid-row-count*)
  (assert *%window-column*)
  (assert *%window-row*)
  (when (and *window-border*
	           *window-border-chars*)
    (let ((h (char *window-border-chars* 0))
	        (v (char *window-border-chars* 1))
	        (i (char *window-border-chars* 2))
	        (*%background-color-code* *%window-border-background-color-code*)
	        (*%foreground-color-code* *%window-border-foreground-color-code*))
      (declare (special *%background-color-code* *%foreground-color-code*))
      (flet ((hline (y)
	             (setf *row* y
		                 *col* *%window-column*)
	             (if (zerop *%grid-column-count*)
		               (write-to-change-buffer i t)
		               (incf *col*))
	             (dotimes (% *window-width*)
		             (write-to-change-buffer h t))
	             (write-to-change-buffer i t))
	           (vline (y)
	             (when (zerop *%grid-column-count*)
		             (setf *col* *%window-column*
		                   *row* y)
		             (write-to-change-buffer v t))
	             (setf *col* (+ *%window-column*
				                                      *window-width*
				                                      1)
		                 *row* y)
	             (write-to-change-buffer v t)))
	      (hline *%window-row*)
	      (dotimes (i *window-height*)
	        (let ((y (+ *%window-row*
		                  i
		                  1)))
	          (vline y)))
	      (hline (+ *%window-row*
		              *window-height*
		              1))))))

(defun %render-window (&rest sprites)
  
  ;; render the stuff
  (mapcar #'%render-sprite sprites)

  ;; add blank lines at the end
  (%maybe-append-blank-lines)
        
  ;; add ASCII border
  (%maybe-render-window-ascii-border))

(defun solo-window* (row column plist &rest sprites)
  (unless *%within-skald-draw*
    (error "WINDOW called outside of SKALD: ~S ~S ~S" row column sprites))
  (with-plist plist
    (with-window-grid row column
      (with-window-grid-column
	      (with-window
	        (apply #'%render-window sprites)))))
  (values))

(defmacro solo-window ((row column
                        &rest kwd-args
		                    &key align bg fg mask transparant-char
		                      width height fill-char
		                      border border-chars border-fg border-bg)
                       &body sprites)
  (declare (ignore align bg fg mask transparant-char
		               width height fill-char
		               border border-chars border-fg border-bg))
  `(solo-window* ,row
	               ,column
	               (list ,@kwd-args)
	               ,@sprites))


;; grids of columns/rows/windows
  
(defmacro with-extend-plist (plist &body body)
  `(let ((*%plist* (append ,plist *%plist*)))
     (declare (special *%plist*))
     ,@body))

(defun window* (plist &rest sprites)
  (unless *%within-skald-draw*
    (error "WINDOW called outside of SKALD: ~S" sprites))
  (assert (boundp '*window-border*))
  (assert (boundp '*%plist*))
  (assert *%grid-row-count*)
  (assert *%window-row*)
  (with-extend-plist plist
    (with-window
      (apply #'%render-window sprites)
      (incf *%window-row*
	          *window-height*)
      (when *window-border*
	      (incf *%window-row*))
      (incf *%grid-row-count*)))
  (values))

(defmacro window ((&rest kwd-args
		                &key align bg fg mask transparant-char
		                  height fill-char)
		               &body sprites)
  (declare (ignore align bg fg mask transparant-char
		               height fill-char))
  `(window* (list ,@kwd-args)
	           ,@sprites))

(defun call-in-column* (plist thunk)
  (assert (boundp '*window-border*))
  (assert (boundp '*%plist*))
  (assert *%window-column*)
  (assert *%grid-column-count*)
  (with-extend-plist plist
    (with-window-grid-column
	    (funcall thunk)
      (incf *%window-column*
	          *window-width*)
      (when *window-border*
	      (incf *%window-column*))
      (incf *%grid-column-count*)))
  (values))

(defmacro column ((&rest kwd-args
		               &key width height align
		                 mask fill-char transparant-char
		                 fg bg)
		              &body windows)
  (declare (ignore width height align mask
		               fill-char transparant-char
		               fg bg))
  `(call-in-column* (list ,@kwd-args)
		                (lambda ()
		                  "COLUMN thunk"
		                  ,@windows)))

(defun call-in-grid* (y x plist thunk)
  (with-plist plist
    (with-window-grid y x
      (funcall thunk)))
  (values))

(defmacro grid ((y x
		             &rest kwd-args
		             &key transparant-char fg bg mask
		                  width height align fill-char
		                  border border-chars border-fg border-bg)
		            &body columns-or-rows)
  (declare (ignore transparant-char fg bg mask
		               width height align fill-char
		               border border-chars border-fg border-bg))
  `(call-in-grid* ,y
		              ,x
		              (list ,@kwd-args)
		              (lambda ()
		                "GRID thunk"
		                ,@columns-or-rows)))





;;;; interpolation helpers

(defun fixed-step-line (&key start-row
                                  start-column
                                  steps-inclusive
                                  end-row
                                  end-column)
  (assert (integerp start-row))
  (assert (integerp start-column))
  (assert (and (integerp steps-inclusive)
               (> steps-inclusive 0)))
  (assert (integerp end-row))
  (assert (integerp end-column))
  (let ((y start-row)
        (x start-column)
        (y-step (/ (- end-row start-row) steps-inclusive))
        (x-step (/ (- end-column start-column) steps-inclusive))
        (points '()))
    (dotimes (step (1+ steps-inclusive))
      (push (cons (floor y)
		  (floor x))
	    points)
      (incf y y-step)
      (incf x x-step))
    (nreverse points)))


;; (defun make-interpolator (&key start-row
;; 			       start-column
;; 			       steps-inclusive
;; 			       end-row
;; 			       end-column)
;;   (assert (integerp start-row))
;;   (assert (integerp start-column))
;;   (assert (and (integerp steps-inclusive)
;; 	       (> steps-inclusive 0)))
;;   (assert (integerp end-row))
;;   (assert (integerp end-column))
;;   (let ((y start-row)
;; 	(x start-column)
;; 	(y-step (/ (- end-row start-row) steps-inclusive))
;; 	(x-step (/ (- end-column start-column) steps-inclusive))
;; 	(step 0))
;;     (lambda ()
;;       (if (>= step steps-inclusive)
;; 	  (values (floor y)
;; 		  (floor x)
;; 		  step)
;; 	  (values (floor (incf y y-step))
;; 		  (floor (incf x x-step))
;; 		  (incf step))))))




;;;; debugging / troubleshooting

  (defun %inspect-buffer-array (buffer &optional (debug-output *terminal-io*))
    (if (null debug-output)
        (with-output-to-string (s)
	        (%inspect-buffer-array buffer s))
        (let ((a (buffer-array buffer))
	            (%empty-array t)
	            %inside-chain)
	        (destructuring-bind (max-row max-column)
	            (array-dimensions a)
	          (dotimes (y max-row)
	            (dotimes (x max-column)
	              (let ((element (aref a y x)))
		              (if (eql element #\nul)
		                  (setf %inside-chain nil)
		                  (if %inside-chain
			                    (format debug-output "~A" element)
			                    (progn
			                      (format debug-output
				                            "~%(~A/~A)~A"
				                            y
				                            x
				                            element)			
			                      (setf %empty-array nil
				                          %inside-chain t))))))))
	        (when %empty-array
	          (format debug-output "Empty array"))
	        (values))))
