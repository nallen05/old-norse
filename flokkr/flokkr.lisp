

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

(defun seconds-until-itu (itu-time &optional (now-itu-time (get-internal-real-time)))
  (/ (- itu-time now-itu-time)
     internal-time-units-per-second))

(defun sleep-until-itu (itu-time &optional (now-itu-time (get-internal-real-time)))
  (let ((seconds (seconds-until-itu itu-time now-itu-time)))
    (when (plusp seconds)
      (sleep seconds))))


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

  

(defvar *flokkr-input-read-flag* nil)

(defmacro %flokkr (&body clauses)
  (let ((start-now (gensym "flokkr-start-now-"))
        (activated (gensym "flokkr-activated-"))
        (input-matched (gensym "flokkr-input-matched-"))
        (global-run-timer (gensym "flokkr-run-global-wait-"))
        lexical-state
        body-forms
        global-scheduler-forms)
    (dolist (c clauses)
      (case (first c)
        (:input (push `(progn
                         (unless *flokkr-input-read-flag*
                           (bifrost:rune-read-no-hang)
                           (setf *flokkr-input-read-flag* t))
                         (when bifrost:*rune*
                           (unless ,input-matched
                             (bifrost:rune-case bifrost:*rune*
                               ,@(mapcar (lambda (in-case)
                                           `(,@in-case
                                             (setf ,activated t
                                                   ,input-matched t)))
                                         (rest c))))))
                      body-forms))
        (:also (push `(when ,activated
                        ,@(rest c))
                     body-forms))
        (:subflokkr
         (let ((subflokkr (gensym "flokkr-"))
               (subtimer (gensym "subflokkr-timer-")))
           (push `(,subflokkr ,(second c))
                 lexical-state)
           (push `(,subtimer ,start-now)
                 lexical-state)
           (push `(progn
                    (setq ,subtimer (funcall ,subflokkr))
                    ;; subflokkr THUNK must return an ITU time or NIL
                    (assert (or (not ,subtimer)
                                (numberp ,subtimer)))
                    (when ,subtimer
                      (setf ,activated t)))
                 body-forms)
           (push `(when ,subtimer
                    (setf ,global-run-timer
                          (if ,global-run-timer
                              (min ,subtimer ,global-run-timer)
                              ,subtimer)))
                  global-scheduler-forms)))
        (otherwise
         (multiple-value-bind (%c timer) (%get-timer-name c)
           (multiple-value-bind (%c init) (%get-initial-wait %c)
             (multiple-value-bind (%c rescheduler) (%get-rescheduler %c timer)
               (case (first %c)
                 (:do
                  (push `(,timer (add-itu-seconds ,init ,start-now))
                        lexical-state)
                  (push `(when (itu-elapsed-p ,timer)
                           (setf ,activated t)
                           ,@(rest %c)
                           ,rescheduler)
                           body-forms)
                  (push `(when ,timer
                           (setf ,global-run-timer
                                 (if ,global-run-timer
                                     (min ,timer ,global-run-timer)
                                     ,timer)))
                        global-scheduler-forms))
                 (otherwise (error "FLOKKR clause not recognized as :DO, :INPUT, :ALSO, or :SUBFLOKKR form: ~A" c)))))))))
    `(let* ((,start-now (get-internal-real-time))
            ,@(reverse lexical-state))
       (lambda ()
         (let (,activated
               ,input-matched
               ,global-run-timer)
           (declare (ignorable ,activated ,input-matched))
           (setf ,start-now (get-internal-real-time))
           ,@(reverse body-forms)
           ,@(reverse global-scheduler-forms)
           (if (and *flokkr-input-read-flag*
                    (bifrost:rune-listen))
               ,start-now
               ,global-run-timer))))))



;; core runtime

(defun flokkr-run (thunk)
  "Main event loop: call thunk, wait for duration or input, repeat forever"
  (let ((global-run-timer (get-internal-real-time)))
    (bifrost:with-bifrost
      (loop
        do (let ((*flokkr-input-read-flag* *flokkr-input-read-flag*))
             (declare (special *flokkr-input-read-flag*))
             (setq global-run-timer (funcall thunk))
;;             (format bifrost:*bifrost-io* "~%grt=~A irf=~A" global-run-timer *flokkr-input-read-flag*)
             
             ;; THUNK must return an itu time or NIL
             (assert (or (not global-run-timer)
                         (numberp global-run-timer)))

             (if *flokkr-input-read-flag*

                 ;; there is an :INPUT clause inside of THUNK
                 ;; if there is no input available, then until next input, up to DURATION
                 (when (or (not global-run-timer)
                           (plusp global-run-timer))
                   (if bifrost:*bifrost-tty-p*

                       ;; we're inside a Unix-like terminal emulator, so we can react instantly
                       ;; to user input
                       (sb-sys:wait-until-fd-usable bifrost:*bifrost-tty-p*
                                                    :input (let ((seconds (seconds-until-itu global-run-timer)))
                                                             (when (plusp seconds)
                                                               seconds)))

                       ;; we're outside of a Unix-like terminal emulator, in read-debug mode
                       ;; so fall back on inefficient polling :-(
                       (let ((default-input-polling-timer (add-itu-seconds 0.02)))
                         (sleep-until-itu (if global-run-timer
                                              (min global-run-timer
                                                   default-input-polling-timer)
                                              default-input-polling-timer)))))

                 ;; there is no :INPUT clause inside of THUNK
                 ;; if there are any active timers, keep going
                 ;; if not, then exit
                 (if global-run-timer
                     (sleep-until-itu global-run-timer)
                     (return-from flokkr-run))))))))

;; main API entrypoint

(defmacro flokkr (&body clauses)
  `(block flokkr
     (flokkr-run (%flokkr ,@clauses))))

(defmacro subflokkr (&body clauses)
  `(%flokkr (block subflokkr
              ,@clauses)))
