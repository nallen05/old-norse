

(defpackage :flokkr
  (:use :cl)
  (:export ;; main API
           :flokkr

           ;; timer manipulation API
           :flokkr-reschedule
           :flokkr-delay

           ;; creating subflokkrs to be composed seperately
            :subflokkr))

(in-package :flokkr)

;; ITU utilities

(assert (equal 1000000 internal-time-units-per-second))

(defun add-itu-seconds (delta-seconds &optional (itu-time (get-internal-real-time)))
  (+ itu-time
     (floor (* delta-seconds
               internal-time-units-per-second))))

(defun itu-elapsed-p (itu-time &optional (now-itu-time (get-internal-real-time)))
  (or (null itu-time)
      (>= now-itu-time itu-time)))



;; timer manipulation API

(defmacro flokkr-reschedule (timer seconds-or-nil)
  "Set timer to fire SECONDS-OR-NIL from now, or disable if NIL"
  (let ((duration (gensym "flokkr-reschedule-seconds")))
    `(let ((,duration ,seconds-or-nil))
       (setf ,timer
             (if ,duration
                 (add-itu-seconds ,duration)
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
                       (cons 1st (rfn rest)))))))
      (values (rfn clauses)
              initial-wait))))


(defun %get-rescheduler (clauses timer-name)
  (let (rescheduler)
    (labels ((rfn (_)
               (when _
                 (destructuring-bind (1st . rest) _
                   (cond
                     ((eql 1st :reschedule)
                      (when (cdr rest)
                        (warn "FLOKKR: anything after :RESCHEDULE SECONDS will be ignored (~a)" (cdr rest)))
                      (setf rescheduler
                            `(flokkr-reschedule ,timer-name ,(car rest)))
                      nil)
                     ((eql (first rest) :reschedule-dynamic)
                      (when (cdr rest)
                        (warn "FLOKKR: anything after :RESCHEDULE-DYNAMIC will be ignored (~a)" (cdr rest)))

                      (setf rescheduler
                            `(flokkr-reschedule ,timer-name ,1st))
                      nil)
                     (t (cons 1st (rfn rest))))))))
      (values (rfn clauses)
              rescheduler))))

(defmacro subflokkr (&rest clauses)
  (let ((activated (gensym "flokkr-activated-"))
        (input-matched (gensym "flokkr-input-matched-"))
        (next-wait (gensym "flokkr-next-wait-"))
        lexical-state
        body-forms)
    (dolist (c clauses)
      (case (first c)
        (:input (push `(when bifrost:*rune*
                         (unless ,input-matched
                           (bifrost:rune-case bifrost:*rune*
                                             ,@(mapcar (lambda (in-case)
                                                         `(,@in-case
                                                           (setf ,activated t
                                                                 ,input-matched t)))
                                                       (rest c)))))
                      body-forms))
        (:also (push `(when ,activated
                        ,@(rest c))
                     body-forms))
        (:subflokkr
         (let ((subflokkr (gensym "flokkr-"))
               (subtimer (gensym "flokkr-timer-")))
           (push `(,subflokkr ,(second c))
                 lexical-state)
           (push `(let ((,subtimer (funcall ,subflokkr)))
                    (when ,subtimer
                      (setf ,activated t)
                      (setf ,next-wait
                            (if ,next-wait
                                (min ,subtimer ,next-wait)
                                ,subtimer))))
                  body-forms)))
        (otherwise
         (format t "~%1~s" c)
         (multiple-value-bind (%c timer) (%get-timer-name c)
           (format t "~%2~s" %c)
           (multiple-value-bind (%c init) (%get-initial-wait %c)
             (format t "~%3~s" %c)
             (multiple-value-bind (%c rescheduler) (%get-rescheduler %c timer)
               (format t "~%4~s" %c)
               (case (first %c)
                 (:do
                  (push `(,timer ,init)
                        lexical-state)
                  (push `(if (itu-elapsed-p ,timer)
                             (progn
                               (setf ,activated t)
                               ,@(rest %c)
                               ,rescheduler)
                             (when ,timer
                               (setf ,next-wait
                                     (if ,next-wait
                                         (min ,timer ,next-wait)
                                         ,timer))))
                        body-forms))
                 (otherwise (error "FLOKKR clause not recognized as :DO, :INPUT, :ALSO, or :SUBFLOKKR form: ~A" c)))))))))
    `(let ,(reverse lexical-state)
       (lambda ()
         (let (,activated
               ,input-matched
               ,next-wait)
           (declare (ignorable ,activated ,input-matched))
           ,@(reverse body-forms)
           ,next-wait)))))



;; core runtime

(defun flokkr-run (thunk)
  "Main event loop: call thunk, wait for duration or input, repeat forever"
  (let ((duration 0)
        (fd (when (typep *terminal-io* 'sb-sys:fd-stream)
              (sb-sys:fd-stream-fd *terminal-io*))))
    (unless fd
      (warn "FLOKKR: *TERMINAL-IO* is not a SB-SYS:FD-STREAM-FD. This means that FLOKKR is probably being called within SLIME/EMACS. Falling back to polling for user input. FLOKKR is optimized to be run in the terminal"))
    (tagbody
     start       
       ;; if there is input, process it immediately
       ;; keep processing until no more input is available
       (when (bifrost:rune-read-no-hang *terminal-io*)
         (setq duration (funcall thunk))
         (go start))

       ;; THUNK must return a duration (number of seconds) or NIL
       (assert (or (not duration)
                   (numberp duration)))
         
       (if fd

           ;; no input available, wait for duration or next input
           (when (or (not duration)
                     (plusp duration))
             (sb-sys:wait-until-fd-usable fd :input duration))

           ;; we're in polling mode, so just sleep for a short time
           (unless (and duration
                        (< duration 0.01))
             (sleep (min duration 0.01))))

       ;; repeat
       (go start))))



;; main API entrypoint

(defmacro flokkr (&rest clauses)
  `(block flokkr
     (flokkr-run (subflokkr ,@clauses))))
