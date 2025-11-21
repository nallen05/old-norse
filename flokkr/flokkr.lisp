

;; issue inbox
;; - will RETURN inside a FLOKKR-MAIN clause actually escape?
;;   or does the SUBFLOKKR closure need to return a second value to indicate status?
;; - once an :INPUT has been triggered, subsequent :INPUTs should be ignored
;; - unknown keywords, or keywords in bad places


;; ITU utilities

(assert (equal 1000000 internal-time-units-per-second))

(defun add-itu-seconds (delta-seconds &optional (itu-time (get-internal-real-time)))
  (+ itu-time
     (floor (* delta-seconds
               internal-time-units-per-second))))

(defun itu-elapsed-p (itu-time &optional (now-itu-time (get-internal-real-time)))
  (or (null itu-time)
      (>= now-itu-time itu-time)))


;; LOOP-inspired keyword mini-language


(defun %get-timer-name (clauses)
  (let (timer-name)
    (labels ((rfn (_)
               (when _
                 (destructuring-bind (1st . rest) _
                   (if (eq 1st :with-named-timer)
                       (progn
                         (setf timer-name (car rest))
                         (cdr rest))
                       (cons 1st (rfn rest)))))))
      (values (rfn clauses)
              (or timer-name
                  (gensym "timer-"))))))

(defun %get-initial-wait (clauses)
  (let ((initial-wait 0))
    (labels ((rfn (_)
               (when _
                 (destructuring-bind (1st . rest) _
                   (if (eq 1st :after)
                       (progn
                         (setf initial-wait (car rest))
                         (cdr rest))
                       (rfn rest))))))
      (values (rfn clauses)
              initial-wait))))


(defun %get-rescheduler (clauses timer-name)
  (let (rescheduler)
    (labels ((rfn (_)
               (when _
                 (destructuring-bind (1st . rest) _
                   (cond
                     ((eql 1st :reschedule)
                      (setf rescheduler
                            `(flokkr-reschedule ,timer-name ,(car rest)))
                      nil)
                     ((eql (first rest) :reschedule-dynamic)
                      (setf rescheduler
                            `(flokkr-reschedule ,timer-name ,1st))
                      nil)
                     (t (rfn rest)))))))
      (values (rfn clauses)
              rescheduler))))

(defmacro subflokkr (&rest clauses)
  (let ((next-wait (gensym "subflokkr-next-wait-"))
        (activated (gensym "subflokkr-activated-"))
        lexical-state
        body-forms)
    (dolist (c clauses)
      (case (first c)
        (:input (push `(when bifrost:*rune*
                         (setf ,activated t)
                         (bifrost:rune-case *rune* ,@(rest c)))
                      body-forms))
        (:also (push `(when ,activated
                        ,@(rest c))
                     body-forms))
        (:subflokkr
         (let ((subflokkr (gensym "subflokkr-"))
               (subtimer (gensym "subflokkr-timer-")))
           (push `(,subflokkr ,(second c))
                 lexical-state)
           (push `(let ((,subtimer (funcall ,subflokkr)))
                    (when ,subtimer
                      (setf ,activated t)
                      (setf ,next-wait
                            (if (not ,next-wait)
                                ,subtimer
                                (min ,subtimer ,next-wait)))))
                  body-forms)))
        (otherwise
         (multiple-value-bind (c timer) (%get-timer-name c)
           (multiple-value-bind (c init) (%get-initial-wait c)
             (multiple-value-bind (c rescheduler) (%get-rescheduler c timer)
               (ecase (first c)
                 (:do
                  (push `(,timer ,init)
                        lexical-state)                 
                  (push `(if (itu-elapsed-p ,timer)
                             (progn
                               (setf ,activated t)
                               ,@c
                               ,rescheduler)
                             (when ,timer
                               (setf ,next-wait
                                     (if (not ,next-wait)
                                         ,timer
                                         (min ,timer ,next-wait)))))
                   body-forms)))))))))
    `(let ,lexical-state
       (lambda ()
         (let (,next-wait)
           ,@body-forms)))))



;; timer manipulation API


(defmacro flokkr-reschedule (timer seconds-or-nil)
  "Set timer to fire SECONDS-OR-NIL from now, or disable if NIL"
  (let ((duration (gensym "flokkr-reschedule-seconds")))
    `(let ((,duration ,seconds-or-nil))
       (setf ,timer
             (if ,duration
                 `(add-itu-seconds ,duration)
                 nil)))))

(defmacro flokkr-delay (timer delta-seconds-or-nil)
  "Delay (positive) or accelerate (negative) an active timer. Timers that are already off stay off."
  (let ((%timer (gensym "flokkr-timer"))
        (delta (gensym "flokkr-delay-seconds")))
    `(let ((,%timer ,timer)
           (,delta ,delta-seconds-or-nil))
       (when ,%timer
         (setf ,timer
               (when ,delta
                 (add-itu-seconds ,delta ,%timer)))))))


;; core runtime

(defun flokkr-run (thunk)
  "Main event loop: call thunk, wait for duration or input, repea forevert"
  (let ((duration 0))
    (block nil        ;; can escape with RETURN
      (tagbody
       start       
         ;; if there is input, process it immediately
         ;; keep processing until no more input is available
         (when (bifrost:rune-read-no-hang *terminal-io*)
           (setq duration (funcall thunk))
           (go start))

         ;; THUNK must always return a duration (number of seconds) or NIL
         (assert (or (not duration)
                     (numberp duration)))
         
         ;; no input available, wait for duration or next input
         (when (or (not duration)
                   (plusp duration))
           (sb-sys:wait-until-fd-usable (sb-sys:fd-stream-fd *terminal-io*)
                                        :input duration))

         ;; repeat
         (go start)))))


;; main API entrypoint

(defmacro flokkr-main (&rest clauses)
  `(flokkr-run (subflokkr ,@clauses)))
