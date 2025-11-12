






;;;;;;;; lib-multitask
;;
;; cooperative multitasking API for GUIs running on single threaded TTY
;;
;; to be moved to old-norse
;;


;;;; API
;;
;;  FLOKKR(seconds-or-bool &optional itu-now)
;;    create a timer, based on SECONDS-OR-BOOL:
;;      (make-timer number) -> ITU time that is NUMBER seconds in the future
;;      (make-timer t)      -> t
;;      (make-timer nil)    -> nil
;;
;;  FLOKKR-READY-P(itu-time &optional itu-now)
;;    timer is passed
;;
;;  FLOKKR-TILL(timer)
;;    return seconds-or-bool
;;
;;  LOOP-FLOKKR (frequency &body cases)
;;    conditionally runs CASES every DURATION seconds until one of the cases calls RETURN
;;    cases have the following syntax:
;;       (ALWAYS . BODY)
;;           always execute BODY
;;       (t . BODY)
;;           always executes BODY
;;       (ALARM . BODY)
;;           execute BODY & then set ALARM based on the return value of BODY using #'FLOKKR
;;           after that, case only executed if (or (NULL ARLARM)
;;                                                 (< ALARM (GET-INTERNAL-REAL-TIME)))
;;       ((ALARM :INIT T) . BODY)
;;           this is the same as (ALARM . BODY)
;;       ((ALARM :INIT NIL) . BODY)
;;           BODY is never run until the body of another case sets ALARM to a non null value
;;       ((ALARM :INIT SECONDS) . BODY)
;;           just like (ALARM . BODY), except that LOOP-FLOKKR doesn't run BODY for the first
;;           time until after SECONDS seconds have gone by
;;       ((ALARM :SPECIAL T) . BODY)
;;           if :SPECIAL is provided, then ALARM is treated as a variable that exists outside of
;;           the scope of LOOP-FLOKKR. The timer can be set before running LOOP-FLOKKR & the
;;           state of the timer can be passed to downstream calls to LOOP-FLOKKR or other code.
;;           if :SPECIAL is provided, then :INIT is ignored
;;
;;

;;;; OPTIONAL CONVENTION
;;
;; suggested prefix naming convention to use with this lib:
;;
;;   [t]-time       an ITU time, like the one returned by GET-INTERNAL-REAL-TIME
;;   [d]-duration   duration of seconds (not ITU) to wait
;;   [n]-ticks      number of ticks/frames (eg for an animation)
;;   [%]-progress   for tracking transition from 0.0 to 1.0
;;






;; working w/ internal real time (ITU)
(assert (equal 1000000 internal-time-units-per-second))

(defun %itu-add-seconds (delta-seconds &optional (itu-time (get-internal-real-time)))
  (+ itu-time (floor (* delta-seconds internal-time-units-per-second))))


;; api
   
(defun flokkr (seconds-or-bool &optional (now-itu (get-internal-real-time)))
  (case seconds-or-bool
    ((t nil) seconds-or-bool)
    (otherwise
     (if (numberp seconds-or-bool)
	 (%itu-add-seconds seconds-or-bool now-itu)
	 (error "FLOKKR expects a number of seconds, T, or NIL. Got ~S instead"
		seconds-or-bool)))))

(defun flokkr-ready-p (itu-or-bool &optional (now-itu (get-internal-real-time)))
  (case itu-or-bool
    ((t nil) itu-or-bool)
    (otherwise
     (if (numberp itu-or-bool)
	 (>= now-itu
	     (%itu-add-seconds 0 itu-or-bool))
	 (error "FLOKKR-READY-P expects an ITU time, T, or NIL. Got ~S instead"
		itu-or-bool)))))

(defun flokkr-till (itu-or-bool &optional (itu-now (get-internal-real-time)))
  (case itu-or-bool
    ((t nil) itu-or-bool)
    (otherwise
     (if (numberp itu-or-bool)
	 (let ((seconds (/ (- itu-or-bool itu-now)
			   internal-time-units-per-second)))
	   (values (round seconds)
		   seconds))
	 (error "FLOKKR-TILL expects an ITU time, T, or NIL. Got ~S instead"
		itu-or-bool)))))


 
(defmacro loop-flokkr (frequency &body cases)
  (let ((freq (gensym "loop-flokkr-frequency"))
	(%cases (mapcar (lambda (alarm-case)
			  (destructuring-bind (alarm . case-forms)
			      alarm-case
			    (if (and alarm
				     (listp alarm))
				alarm-case
				`((,alarm) ,@case-forms))))
			cases)))
    `(block nil
       (let ((,freq ,frequency)
	     ,@(remove nil
		       (mapcar (lambda (alarm-case)
				 (destructuring-bind ((a &key (init t) special) &body body)
				     alarm-case
				   (declare (ignore body))
				   (when (and a
					      (not special)
					      (not (eql a t))
					      (not (eql a 'always)))
				     `(,a (flokkr ,init)))))
			       %cases)))
	 (loop (progn
		 ,@(mapcar (lambda (alarm-case)
			     (destructuring-bind ((a &key init special) &body body)
				 alarm-case
			       (declare (ignore init special))
			       (cond

				 ;; code will always run
				 ((or (eq a t)
				      (eq a 'always))
				  `(progn ,@body))

				 ;; code will never run
				 ((null a)
				  `(when nil ,@body))

				 ;; conditional
				 (t 
				  `(when (flokkr-ready-p ,a)
				     (setf ,a
					   (flokkr (progn ,@body))))))))
			   %cases)
		 (sleep ,freq)))))))


;; (defvar *last-rune-read* nil)      ;; move to RUNE-READ

;; (defmacro loop-flokkr-input ((frequency &body flokkr-cases) &body input-cases)
;;   `(loop-flokkr ,frequency
;;      ,@flokkr-cases
;;      (t (case (setf *last-rune-read*
;; 		    (rune-read-no-hang))
;; 	  ,@input-cases))))









;;;;;;;; CLICKAROUND TESTS


#+nil
(defun test-flokkr-cooloff ()
  (loop-flokkr 0.5
    (t      (format t "~%pulse"))
    (timer1 (format t "~%  TIMER_1")
	    t)
    (timer2 (format t "~%  TIMER_2")
            1)
    (timer3 (format t "~%  TIMER_3 (SLOW)")
            3)
    (timer4 (format t "~%  TIMER_4 (ONCE)")
	    nil)))
#+nil
(defun test-flokkr-delay ()
  (loop-flokkr 1
    (always (format t "~%tick"))
    ((timer1 2) (format t "    TIMER_1")
                1)
    ((timer2 4)  (format t "    DELAYED TIMER_2")
                1)
    ((timer3 6)  (format t "    DELAYED TIMER_3 (ONCE)")
                nil)))
    

  
