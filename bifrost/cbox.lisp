




(in-package :bifrost)



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
	         (rune-write (list :mouse-reporting ,%m t) ,%s)
	         (rune-write (list :sgr-mouse-reporting t) ,%s)
	         (force-output ,%s))
         (unwind-protect (progn ,@body)
	         (when ,%m
	           (rune-write (list :mouse-reporting ,%m nil) ,%s))
	         (force-output ,%s))))))





;;;; setup: defining CBOX click regions

(defvar *%within-with-cbox-p* nil)
(defvar *cbox-stack*          nil)

(defmacro with-cbox (clear-p &body body)
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

;; (defun rune-read-no-hang (&optional (stream *terminal-io*))
;;   (multiple-value-bind (rune)
;;       (rune-read-raw-no-hang stream)
;;     (rune-case rune
;;
;;       ;; nothing to read
;;       (nil
;;        nil)
;;
;;       ;; currently unsupported mouse events
;;       (:mouse-click-right  nil)
;; 	    (:mouse-click-middle nil)
;; 	    (:mouse-move         nil)
;;
;;       ;; mouse click down
;;       (:mouse-click-left
;;        (ecase *bifrost-mouse-tracking-mode*
;;          (1000          
;;           (let ((cbox (lookup-cbox (second rune)
;;                                    (third rune))))
;;             (cond
;;               (cbox
;;                (setf *cbox*         cbox
;;                      *active-cbox-pressed* cbox)
;;                (cons :cbox-click-left
;;                      (rest rune)))
;;               (t
;;                (setf *cbox* nil
;;                      *active-cbox-pressed* nil)
;;                nil))))
;;            
;;          ((nil)
;;           (setf *cbox* nil
;;                 *active-cbox-pressed* nil)
;;           nil)))
;;
;;       ;; mouse click release / unrelease
;;       (:mouse-release
;;        (case *bifrost-mouse-tracking-mode*
;;          (1000
;;           (let ((cbox (lookup-cbox (second rune)
;;                                    (third rune))))
;;             (cond
;;               ((and cbox
;;                     (eq cbox *active-cbox-pressed*))   ;; important line
;;                (setf *cbox*           cbox
;;                      *active-cbox-pressed* nil)
;;                (cons :cbox-release-left
;;                      (rest rune)))
;;                     
;;               (t
;;                (setf *cbox* nil
;;                      *active-cbox-pressed* nil)
;;                (cons :cbox-unclick-left
;;                      (rest rune))))))
;;          ((nil)
;;           (setf *cbox* nil
;;                 *active-cbox-pressed* nil)
;;           nil)))
;;
;;       ;; any other rune
;;       (otherwise
;;        (setf *cbox* nil
;;              *active-cbox-pressed* nil)
;;        rune))))

;; (defun rune-read-no-hang (&optional (stream *terminal-io*))
;;   (rune-read-raw-no-hang stream)
;;   (setf *cbox* nil
;;         *active-cbox-pressed* nil)
;;   (when (find *rune-name*
;;               '(:mouse-click-left
;;                 :mouse-release))
;;     (destructuring-bind (row column)
;;         *rune-payload*
;;       (let ((cbox (lookup-cbox row column)))
;;          (case *rune-name*
;;            (:mouse-click-left
;;             (when cbox
;;               (setf *cbox*                cbox
;;                     *active-cbox-pressed* cbox)
;;               (return-from rune-read-no-hang
;;                 (cons :cbox-click-left
;;                       *rune-payload*))))
;;            (:mouse-release
;;             (if (and cbox
;;                      (eq cbox *active-cbox-pressed*))   ;; important line
;;                 (progn
;;                   (setf *cbox* cbox)
;;                   (return-from rune-read-no-hang
;;                     (cons :cbox-release-left
;;                           *rune-payload*)))
;;                 (return-from rune-read-no-hang
;;                   (cons :cbox-unclick-left
;;                         *rune-payload*))))
;;            (otherwise nil)))))
;;   *rune*)

;; (defun rune-read (&optional (stream *terminal-io*))
;;   (loop (let ((rune (rune-read-no-hang stream)))
;; 	        (if rune
;; 	            (return-from rune-read
;; 		            rune)
;; 	            (sleep *rune-read-poll-frequency*)))))


(defun rune-read-no-hang ()
  (rune-read-raw-no-hang)
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



(defun rune-read ()
  (loop (multiple-value-bind (rune cbox)
            (rune-read-no-hang)
          (if rune
              (return-from rune-read
                (values rune
                        cbox))
              (sleep *rune-read-poll-frequency*)))))



