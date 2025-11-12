

;;;;;;;;;;;;;;;
;;
;; FLOKKR
;;
;; a cooperative multitasking library for Common Lisp, purpose built for building interactive
;; terminal applications
;;
;; In old norse, flokkr means "flying swam". It's also the word for a type of Skaldic poem.
;;
;;
;;
;; THERE ARE CLICKAROUND TESTS AT THE BOTTOM OF THIS FILE
;;
;;
;;
;; TODO
;;  * better to add the duration during timer creation, then remove the extra parens
;;    from the macros that reference
;;  * review decision: internal time units vs universal time
;;  * DEFPACKAGE + naming
;;     - can remove "itu" from some of the function names?
;;  * add documentation. explain why fits terminal UI
;;  * proper -MULTITASKING / -ASYNC versions of UNTIL-COOLED-OFF
;;  * refactor to lower GC pressure
;;    - Use scratch arena insead of allocating structs?


;; working w/ internal real time (ITU)

(assert (equal 1000000 internal-time-units-per-second))

(defun add-itu-seconds (delta-seconds &optional (itu-time (get-internal-real-time)))
  (+ itu-time (floor (* delta-seconds internal-time-units-per-second))))

(defmacro with-itu-timer ((name &optional (seconds-cooldown 0)) &body body)
  `(let ((,name (add-itu-seconds ,seconds-cooldown)))
     ,@body))

(defun itu-elapsed-p (itu-time &optional (seconds-cooldown 0) (now-itu-time (get-internal-real-time)))
  (or (null itu-time)
      (>= now-itu-time
	  (add-itu-seconds seconds-cooldown itu-time))))

(defun seconds-until-itu (itu-time &optional (itu-now (get-internal-real-time)))
  (let ((xx (/ (- itu-time itu-now) internal-time-units-per-second)))
    (values (round xx)
	    xx)))

(defun sleep-until-itu (itu-time &optional (now-itu-time (get-internal-real-time)))
  (multiple-value-bind (rounded exact)
      (seconds-until-itu itu-time now-itu-time)
    (declare (ignore rounded))
     (when (> exact 0)
       (sleep exact))))

(defun print-itu (&optional (itu-time (get-internal-real-time) stream))
  (let* ((now-itu (get-internal-real-time))
         (seconds-difference (round (/ (- now-itu itu-time) internal-time-units-per-second)))
         (current-universal-time (get-universal-time))
         (target-universal-time (- current-universal-time seconds-difference)))
    (multiple-value-bind (second minute hour date month year) (decode-universal-time target-universal-time)
      (format stream
	      "~A-~2,'0D-~2,'0D ~2,'0D:~2,'0D:~2,'0D"
              year month date hour minute second)
      )))



;; rate-limiting mechanism & time-based triggers

;; (defmacro touch (itu-place &optional (seconds 0))
;;   "Set ITU-PLACE to the current ITU time or a future ITU time by adding SECONDS"
;;   `(setf ,itu-place
;; 	 (+ (get-internal-real-time)
;;             (floor (* ,(or seconds 0) internal-time-units-per-second)))))

;; (defmacro if-cooled-off ((itu (seconds 0)) then &optional else)
;;   "Execute THEN if SECONDS after ITU time has passed, otherwise execute ELSE."
;;   `(if (<= (+ ,itu (floor (* ,(or seconds 0) internal-time-units-per-second)))
;;            (get-internal-real-time))
;;        ,then
;;        ,else))

(defmacro touch (itu-place &optional (seconds 0))
  "Set ITU-PLACE to the current ITU time or a future ITU time by adding SECONDS"
  `(setf ,itu-place (add-itu-seconds ,seconds)))

(defmacro if-cooled-off ((itu &optional (seconds 0)) then &optional else)
  "Execute THEN if SECONDS after ITU time has passed, otherwise execute ELSE."
  `(if (itu-elapsed-p ,itu ,seconds)
       ,then
       ,else))

(defmacro when-cooled-off ((itu &optional (seconds 0)) &body body)
  "Execute BODY if SECONDS after ITU time has passed."
  `(if-cooled-off (,itu ,seconds)
		  (progn ,@body)))

(defmacro unless-cooled-off ((itu &optional (seconds 0)) &body body)
  "Execute BODY unless SECONDS after ITU time has passed."
  `(if-cooled-off (,itu ,seconds)
		  nil
		  (progn ,@body)))

(defmacro until-cooled-off ((itu &optional (seconds 0)) &body body)
  "Sleep until the timer ITU is ready (if it is too soon)."
  `(progn
     (sleep-until-itu (+ ,itu (floor (* ,seconds internal-time-units-per-second)))
     ,@body)))


;; scheduled tasks
		  
(defvar *scheduled-tasks* nil)

(defmacro with-tasks ((&optional (tasks t)) &body body)
  (let ((%tasks (gensym "tasks")))
    `(let* ((,%tasks ,tasks)
	    (*scheduled-tasks* (copy-list (if (eql ,%tasks t)
					      (if (boundp '*scheduled-tasks*)
						  *scheduled-tasks*
						  nil)
					      ,%tasks))))
       (declare (special *scheduled-tasks*))
       ,@body)))

(defstruct (task (:constructor %make-task))
  scheduled-itu-time
  thunk)

(defun make-task (seconds thunk)
  (assert (and (numberp seconds)
	       (>= seconds 0)))
  (assert (functionp thunk))
  (%make-task :scheduled-itu-time (add-itu-seconds seconds)
	      :thunk thunk))

(defun %schedule-task! (task)
  (assert (task-p task))
  (pushnew task *scheduled-tasks*)         ;; could be more efficient
  (setf *scheduled-tasks*
	(sort *scheduled-tasks*
	      #'<
	      :key #'task-scheduled-itu-time))
  task)

(defmacro schedule (seconds &body body)
  `(%schedule-task! (make-task ,seconds (lambda () ,@body))))

(defvar *task*)

(defun run-tasks (&key timeout)
  (let ((stop-at (when timeout
		   (if (and (numberp timeout)
			    (>= timeout 0))
		       (add-itu-seconds timeout)
		       (progn
			 (warn "RUN-TASKS called with bad TIMEOUT ~S. ignoring" timeout)
			 nil)))))
    (loop (if (or (null *scheduled-tasks*)
		  (and stop-at
		       (< stop-at
			  (get-internal-real-time))))
	      (return-from run-tasks)
	      (let ((*task* (pop *scheduled-tasks*)))
		(declare (special *task*))
		(when (task-scheduled-itu-time *task*)
		  (if (and stop-at
			   (<= stop-at
			       (task-scheduled-itu-time *task*)))
		      (return-from run-tasks)
		      (progn
			(sleep-until-itu (task-scheduled-itu-time *task*))
			(funcall (task-thunk *task*))))))))))

(defun schedule-next (seconds &optional (task *task*))
  (assert (or (null seconds)
	      (and (numberp seconds)
		   (>= seconds 0))))
  (setf (task-scheduled-itu-time task)
	(when seconds
	  (add-itu-seconds seconds)))
  (when seconds
    (%schedule-task! task)))


;; control flow variations: blocking

(defun do-multitasking* (thunk &key timeout)
  (assert (functionp thunk))
  (push (make-task 0                              ;; always be first; don't use SCHEDULE
		   (lambda ()
		     (let ((ret (funcall thunk)))
		       (unless (task-scheduled-itu-time *task*)
			 (return-from do-multitasking* ret)))))
	*scheduled-tasks*)
  (run-tasks :timeout timeout))


(defmacro do-multitasking ((&key timeout) &body body)
  `(do-multitasking* (lambda () ,@body)
		      :timeout ,timeout))
  
(defun dolist-multitasking* (fn seconds list &key timeout)
  (assert (functionp fn))
  (assert (numberp seconds))
  (assert (listp list))
  (when list
    (do-multitasking (:timeout timeout)
      (funcall fn (pop list))
      (schedule-next (if list
			 seconds
			 nil)))))

(defmacro dolist-multitasking ((var seconds list &key timeout) &body body)
  `(dolist-multitasking* (lambda (,var) ,@body)
			 ,seconds
			 ,list
			 :timeout ,timeout))

 
(defun dotimes-multitasking* (fn seconds count &key timeout)
  (assert (functionp fn))
  (assert (numberp seconds))
  (assert (numberp count))
  (when (>= count 0)
    (let ((i 0))
      (do-multitasking (:timeout timeout)
	(funcall fn i)
	(incf i)
	(schedule-next (if (< i count)
			   seconds
			   nil))))))

(defmacro dotimes-multitasking ((var seconds count &key timeout) &body body)
  `(dotimes-multitasking* (lambda (,var) ,@body)
			  ,seconds
			  ,count
			  :timeout ,timeout))

(defun until-multitasking* (fn seconds &key timeout)
  (assert (functionp fn))
  (assert (numberp seconds))
  (do-multitasking (:timeout timeout)
    (let ((ret (funcall fn)))
      (cond
	(ret
	 (schedule-next nil)
	 (return-from until-multitasking* ret))
	(t
	 (schedule-next seconds))))))

(defmacro until-multitasking ((seconds &key timeout) &body body)
  `(until-multitasking* (lambda () ,@body)
			,seconds
			:timeout ,timeout))

(defun prog-multitasking* (thunks &key timeout)
  (when thunks
    (do-multitasking (:timeout timeout)
      (let ((thunk (pop thunks)))
	(schedule-next (if thunks
			   0
			   nil))
	(let ((ret (funcall (coerce thunk 'function))))
	  (unless thunks
	    (schedule-next nil)
	    (return-from prog-multitasking*
	      ret)))))))
    
(defmacro prog-multitasking ((&key timeout) &body body)
  `(prog-multitasking* (list ,@(mapcar (lambda (form)
					 `(lambda () ,form))
				       body))
		       :timeout ,timeout))



;; control flow variations: async

(defun async-dolist* (fn seconds list)
  (when list
    (schedule 0
      (funcall fn (pop list))
      (when list
	(schedule-next seconds)))))

(defmacro async-dolist ((var seconds list) &body body)
  `(async-dolist* (lambda (,var) ,@body)
		  ,seconds
		  ,list))

(defun async-dotimes* (fn seconds count)
  (when (>= count 0)
    (let ((i 0))
      (schedule 0
        (funcall fn i)
	(incf i)
	(schedule-next (if (< i count)
			   seconds
			   nil))))))

(defmacro async-dotimes ((var seconds count) &body body)
  `(async-dotimes* (lambda (,var) ,@body)
		  ,seconds
		  ,count))

(defun async-prog* (thunks)
  (when thunks
    (schedule 0
      (when thunks
	(let ((thunk (pop thunks)))
	  (schedule-next (if thunks
			     0
			     nil))
	  (funcall (coerce thunk 'function)))))))
			      
(defmacro async-prog (&body body)
  `(async-prog* (list ,@(mapcar (lambda (form)
				  `(lambda () ,form))
				body))))






;;;; CLICKAROUND TESTS

 
#+ nil
(progn

  ;; testing RUN-TASKS
  (let* ((i 0)
	       (timeout 5)
	       (start (get-internal-real-time))
	       (stop-at (add-itu-seconds timeout start))
	       (tick 0.5))
    (format t "~%--TEST-1----------------------------")
    (format t
	          "~%BGN ~A (~A)"
	          (print-itu start)
	          start)
    (with-tasks ()
      (schedule 0
	              (let ((now (get-internal-real-time)))
	                (format t
		                      "~%  ~A ~A (~A)"
		                      (incf i)
		                      (print-itu now)
		                      now)
	                (schedule-next tick)))
      (run-tasks :timeout timeout))
    (format t
	          "~%END ~A (~A)"
	          (print-itu stop-at)
	          stop-at)
    (format t "~%------------------------------------"))


  ;; testing RUN-TASKS
  (let* ((a 0)
	       (b 0)
	       (timeout 5)
	       (start (get-internal-real-time))
	       (stop-at (add-itu-seconds timeout start)))
    (flet ((tick (worker-name count)
	           (let ((now (get-internal-real-time)))
	             (format t
		                   "~%  ~A.~A ~A (~A)"
		                   worker-name
		                   count
		                   (print-itu now)
		                   now))))
      (format t "~%--TEST-2----------------------------")
      (format t
	            "~%BGN ~A (~A)"
	            (print-itu start)
	            start)
      (with-tasks ()
	      (schedule 0
	                (tick "a" (incf a))
	                (schedule-next 1))
	      (schedule 0
	                (tick "b" (incf b))
	                (schedule-next 0.2))
	      (run-tasks :timeout timeout))
      (format t
	            "~%END ~A (~A)"
	            (print-itu stop-at)
	            stop-at)
      (format t "~%------------------------------------")))

  ;; DO-MULTITASKING
  (let* ((bg 0)
	       (m 0)
	       (timeout 5)
	       (start (get-internal-real-time))
	       (stop-at (add-itu-seconds timeout start)))
    (flet ((tick (worker-name count)
	           (let ((now (get-internal-real-time)))
	             (format t
		                   "~%  ~A.~A ~A (~A)"
		                   worker-name
		                   count
		                   (print-itu now)
		                   now))))
      (format t "~%--TEST-3----------------------------")
      (format t
	            "~%BGN ~A (~A)"
	            (print-itu start)
	            start)
      (with-tasks ()
	      (schedule 0
	                (tick "bg" (incf bg))
	                (schedule-next 0.2))
	      (do-multitasking (:timeout timeout)
	        (tick "m" (incf m))
	        (schedule-next 1)))
      (format t
	            "~%END ~A (~A)"
	            (print-itu stop-at)
	            stop-at)
      (format t "~%------------------------------------")))



  ;; UNTIL-MULTITASKING
  (let* ((bg 0)
	       (m 0))
    (flet ((tick (worker-name count)
	           (let ((now (get-internal-real-time)))
	             (format t
		                   "~%  ~A.~A ~A (~A)"
		                   worker-name
		                   count
		                   (print-itu now)
		                   now))))
      (format t "~%--TEST-4----------------------------")
      (with-tasks ()
	      (schedule 0
	                (tick "bg" (incf bg))
	                (schedule-next 0.2))
	      (until-multitasking (1)
	                          (tick "m" (incf m))
	                          (when (>= m 5)
	                            "done")))))


  ;; DOLIST

  )
