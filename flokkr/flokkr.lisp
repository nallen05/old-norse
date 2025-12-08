

;; INBOX
;;  * drifting subflokkr timers



(defpackage :flokkr
  (:use :cl)
  (:export ;; main API
           :flokkr

           ;; creating subflokkrs to be composed seperately
           :subflokkr

           ;; inspection / debugging
           :*flokkr-elapsed-seconds*
           :*flokkr-step-seconds*))

(in-package :flokkr)


;; vars for debugging / introspection

(defvar *flokkr-elapsed-seconds*)
(defvar *flokkr-step-seconds*)
(defvar *flokkr-tick-input-matched-p*)

;; ITU utilities

(assert (equal 1000000 internal-time-units-per-second))

(defun seconds-between-itu (itu-time-1 itu-time-2)
  (/ (- (max itu-time-1 itu-time-2)
        (min itu-time-1 itu-time-2))
     internal-time-units-per-second))

;; (defun add-itu-seconds (delta-seconds &optional (itu-time (get-internal-real-time)))
;;   (+ itu-time
;;      (floor (* delta-seconds
;;                internal-time-units-per-second))))

;; (defun itu-elapsed-p (itu-time &optional (now-itu-time (get-internal-real-time)))
;;   (or (null itu-time)
;;       (>= now-itu-time itu-time)))

;; (defun seconds-until-itu (itu-time &optional (now-itu-time (get-internal-real-time)))
;;   (/ (- itu-time now-itu-time)
;;      internal-time-units-per-second))

;; (defun sleep-until-itu (itu-time &optional (now-itu-time (get-internal-real-time)))
;;   (let ((seconds (seconds-until-itu itu-time now-itu-time)))
;;     (when (plusp seconds)
;;       (sleep seconds))))



;; timer manipulation API

;; (defmacro flokkr-reschedule (timer seconds-or-nil)
;;   "Set timer to fire SECONDS-OR-NIL from now, or disable if NIL"
;;   (let ((duration (gensym "flokkr-reschedule-seconds")))
;;     `(let ((,duration ,seconds-or-nil))
;;        (setf ,timer
;;              (if ,duration
;;                  (add-itu-seconds ,duration)
;;                  nil)))))

;; (defmacro flokkr-delay (timer delta-seconds-or-nil)
;;   "Delay (positive) or accelerate (negative) an active timer. Timers that are already off stay off."
;;   (let ((%timer (gensym "flokkr-timer"))
;;         (delta (gensym "flokkr-delay-seconds")))
;;     `(let ((,%timer ,timer)
;;            (,delta ,delta-seconds-or-nil))
;;        (when ,%timer
;;          (setf ,timer
;;                (when ,delta
;;                  (add-itu-seconds ,delta ,%timer)))))))



;; LOOP-inspired keyword mini-language

;; (defun %get-timer-name (clauses)
;;   (let (timer-name)
;;     (labels ((rfn (_)
;;                (when _
;;                  (destructuring-bind (1st . rest) _
;;                    (if (eq 1st :with-named-timer)
;;                        (progn
;;                          (setf timer-name (car rest))
;;                          (cdr rest))
;;                        (cons 1st (rfn rest)))))))
;;       (values (rfn clauses)
;;               (or timer-name
;;                   (gensym "timer-"))))))

;; (defun %get-initial-wait (clauses)
;;   (let ((initial-wait 0))
;;     (labels ((rfn (_)
;;                (when _
;;                  (destructuring-bind (1st . rest) _
;;                    (if (eq 1st :after)
;;                        (progn
;;                          (setf initial-wait (car rest))
;;                          (cdr rest))
;;                        (cons 1st (rfn rest)))))))
;;       (values (rfn clauses)
;;               initial-wait))))

;; (defun %get-rescheduler (clauses timer-name)
;;   (let (rescheduler)
;;     (labels ((rfn (_)
;;                (when _
;;                  (destructuring-bind (1st . rest) _
;;                    (cond
;;                      ((eql 1st :reschedule)
;;                       (when (cdr rest)
;;                         (warn "FLOKKR: anything after :RESCHEDULE SECONDS will be ignored (~a)" (cdr rest)))
;;                       (setf rescheduler
;;                             `(flokkr-reschedule ,timer-name ,(car rest)))
;;                       nil)
;;                      ((eql (first rest) :reschedule-dynamic)
;;                       (when (cdr rest)
;;                         (warn "FLOKKR: anything after :RESCHEDULE-DYNAMIC will be ignored (~a)" (cdr rest)))

;;                       (setf rescheduler
;;                             `(flokkr-reschedule ,timer-name ,1st))
;;                       nil)
;;                      (t (cons 1st (rfn rest))))))))
;;       (values (rfn clauses)
;;               rescheduler))))


;; LOOP-inspired keyword mini-language

(defstruct flokkr
  start-tick        ;; (1) start tick: update timers & compute any global delay
  add-global-delay  ;; (2)  apply global delay, if there is any
  execute-clauses   ;; (3) execute activated clauses & rescheduling logic
  compute-wait)     ;; (4) compute how long to wait

(defun %extract-timer-names (clause &aux timer cooloff)
  "clause -> stripped-clause, timer-name, cooloff-name
     :TIMER-NAME -> supplied name or gensym
     :COOLOFF-NAME -> supplied name or NIL"
  (labels ((rfn (_)
             (when _
               (destructuring-bind (1st . rest) _
                 (case 1st
                   (:with-named-timer
                       (if timer
                           (error "FLOKKR: multiple :WITH-NAMED-TIMER forms seen in the same clause (~a)" clause)
                           (progn
                             (setf timer (car rest))
                             (rfn (cdr rest)))))
                   (:with-named-cooloff
                       (if cooloff
                           (error "FLOKKR: multiple :WITH-NAMED-COOLOFF formed seen in the same clause (~a)" clause)
                           (progn
                             (setf cooloff (car rest))
                             (rfn (cdr rest)))))
                   (otherwise (cons 1st (rfn rest))))))))
    (values (rfn clause)
            (or timer
                (gensym "flokkr-timer-"))
            cooloff)))

(defun %extract-init-form (clause &aux (init-form 0) after-seen-p)
  "clause -> transformed-clause, init-form
    :AFTER FORM -> becomes INIT-FORM
    :REPEAT -> becomes :SCHEDULE FORM
    :REPEAT-DRIFT -> becomes :DRIFT FORM"
  (labels ((extract-init (_)
             (when _
               (destructuring-bind (1st . rest) _
                 (if (eq 1st :after)
                     (if after-seen-p
                         (error "FLOKKR: multiple :AFTER forms specified (~a)" clause)
                         (progn
                           (setf init-form (car rest)
                                 after-seen-p t)
                           (extract-init (rest rest))))
                     (cons 1st (extract-init rest))))))
           (replace-repeat (_)
             (when _
               (destructuring-bind (1st . rest) _
                 (case 1st
                   (:repeat
                    (unless after-seen-p
                      (error "FLOKKR: :REPEAT specified without an :AFTER form (~a)" clause))
                    (list* :schedule
                           init-form
                           (replace-repeat rest)))
                   (:repeat-drift
                    (unless after-seen-p
                      (error "FLOKKR: :REPEAT-DRIFT specified without an :AFTER form (~a)" clause))
                    (list* :drift
                           init-form
                           (replace-repeat rest)))
                   (otherwise (cons 1st (replace-repeat rest))))))))
    (values (replace-repeat (extract-init clause))
            init-form)))

(defun %extract-enforce-cooloff (clause &aux enforce-cooloff-form enforce-cooloff-seen-p)
  "clause -> stripped-clause, enforce-cooloff-form, enforce-cooloff-seen-p"
  (labels ((rfn (_)
             (when _
               (destructuring-bind (1st . rest) _
                 (if (eq 1st :enforce-cooloff)
                     (if enforce-cooloff-seen-p
                         (error "FLOKKR: multiple :ENFORCE-COOLOFF forms seen in the same clause (~a)" clause)
                         (progn
                           (setf enforce-cooloff-form (car rest)
                                 enforce-cooloff-seen-p t)
                           (rfn (cdr rest))))
                     (cons 1st (rfn rest)))))))
    (values (rfn clause)
            enforce-cooloff-form
            enforce-cooloff-seen-p)))

(defun %extract-rescheduling-logic (clause &aux reschedule-form reschedule-type)
  "clause -> stripped-clause, reschedule-form, reschedule-type
      reschedule-type -> :schedule | :drift | nil"
  (labels ((rfn (_)
             (when _
               (destructuring-bind (1st . rest) _
                 (case 1st
                   ((:schedule :drift)
                    (when (and reschedule-type
                               (not (eq reschedule-type (car rest))))
                      (error "FLOKKR: cannot mix :SCHEDULE and :DRIFT in the same clause (~a)" clause))
                    (setf reschedule-type 1st
                          reschedule-form (car rest)))
                   (t (cons 1st (rfn rest))))))))
    (values (rfn clause)
            reschedule-form
            reschedule-type)))

(defmacro subflokkr (&body clauses)
  (let ((tick-start-itu (gensym "flokkr-tick-start-itu-"))
        (global-delay-seconds (gensym "flokkr-global-delay-"))
        (activated (gensym "flokkr-activated-"))
        (next-wait (gensym "flokkr-next-wait-"))
        lexical-state
        tick-start-body
        add-global-delay-body
        execute-body
        compute-wait-body)
        
    ;; parse clauses
    (dolist (c clauses)
      (case (first c)
        (:input (push `(when bifrost:*rune*
                         (unless *flokkr-tick-input-matched-p*
                           (case bifrost:*rune*
                             ,@(mapcar (lambda (cases)
                                         `(,@cases
                                           (setf ,activated t
                                                 *flokkr-tick-input-matched-p* t)))
                                (rest c)))))
                      execute-body))
        (:also (push `(when ,activated
                        ,@(rest c))
                     execute-body))
        (:subflokkr
          (destructuring-bind (form &key percolate) ;; <<<>>> subflokkr-drift not yet coded
              (rest c)
            (let ((subflokkr (gensym "subflokkr-"))
                  (subflokkr-ret (gensym "subflokkr-returned-value-")))
              (push `(,subflokkr ,form)
                    lexical-state)
           (push `(let ((,subflokkr-ret (funcall (flokkr-start-tick ,subflokkr))))
                    (when (> ,subflokkr-ret ,global-delay-seconds )
                      (setf ,global-delay-seconds ,subflokkr-ret)))
                 tick-start-body)
           (push `(funcall (subflokkr-add-global-delay ,subflokkr) ,global-delay-seconds)
                 add-global-delay-body)
           (push `(let ((,subflokkr-ret (funcall (subflokkr-execute-clauses ,subflokkr))))
                    (when ,percolate
                      (setf ,activated
                            (or ,subflokkr-ret ,activated))))
                 execute-body)
           (push `(let ((,subflokkr-ret (funcall (flokkr-compute-next-wait ,subflokkr))))
                    (when (or (not ,next-wait)
                              (and ,next-wait ,subflokkr-ret (< ,subflokkr-ret ,next-wait)))
                      (setf ,next-wait ,subflokkr-ret)))
                 compute-wait-body))))
        (otherwise
         (multiple-value-bind (%c timer cooloff) (%extract-timer-names c)
           (multiple-value-bind (%c timer-init-form) (%extract-init-form %c)
           (multiple-value-bind (%c cooloff-form cooloff-seen-p) (%extract-enforce-cooloff %c)
             (multiple-value-bind (%c scheduler-form scheduler-type) (%extract-rescheduling-logic %c)
               (case (first %c)
                 (:do 
                  (push `(,timer ,timer-init-form)
                        lexical-state)
                  (when scheduler-type
                    (push (ecase scheduler-type
                            (:schedule
                             (if cooloff-seen-p
                                 `(progn
                                    (when ,timer
                                      (decf ,timer *flokkr-step-seconds*))
                                    (when ,cooloff
                                      (decf ,cooloff *flokkr-step-seconds*)
                                      (when (and (plusp ,cooloff) ,timer (not (plusp ,timer)))
                                        (unless (>= ,global-delay-seconds ,cooloff)
                                          (setf ,global-delay-seconds ,cooloff)))))
                                 `(when ,timer
                                    (decf ,timer *flokkr-step-seconds*))))
                            (:drift
                             `(when ,timer
                                (decf ,timer *flokkr-step-seconds*))))
                          tick-start-body))
                   (push `(when ,timer
                            (incf ,timer ,global-delay-seconds))
                         add-global-delay-body)
                   (push `(when (and ,timer (not (plusp ,timer)))
                            ,@%c
                            (setf ,activated t)
                            ,@(ecase scheduler-type
                                (:schedule `((setf ,timer ,scheduler-form)))
                                (:drift `((setf ,timer
                                                (let ((_ ,scheduler-form))
                                                  (when _
                                                    (+ _ (seconds-between-itu ,tick-start-itu (get-internal-real-time))))))))
                               (nil nil))
                            ,@(when (and (eq scheduler-type :schedule)
                                         cooloff-seen-p)
                                `((setf ,cooloff (let ((_ ,cooloff-form))
                                                   (when _
                                                     (+ _ (seconds-between-itu ,tick-start-itu (get-internal-real-time)))))))))
                         execute-body)
                   (push `(when (or (not ,next-wait)
                                    (and ,timer (>= ,next-wait ,timer)))
                            (setf ,next-wait ,timer))
                         compute-wait-body))
                 (otherwise (error "FLOKKR: clause not recognized as :DO, :INPUT, :ALSO, or :SUBFLOKKR form: ~A" c))))))))))
        `(let ,(nreverse lexical-state)
           (make-flokkr
            ;; (1) start tick: update timers & compute any global delay
             :start-tick (lambda (&aux (,global-delay-seconds 0))
                           ,@(nreverse tick-start-body)
                           ,global-delay-seconds)
             ;; (2) apply global delay, if there is any
             :add-global-delay (lambda (,global-delay-seconds)
                                 ,@(nreverse add-global-delay-body))
             ;; (3) execute activated clauses & rescheduling logic
             :execute-clauses (lambda (,tick-start-itu &aux ,activated)
                                  (declare (ignorable ,tick-start-itu))
                                ,@(nreverse execute-body))
             ;; (4) compute how long to wait
             :compute-wait (lambda (&aux ,next-wait)
                             ,@(nreverse compute-wait-body)
                             ,next-wait)))))

(defun flokkr-run (flok &aux flok-start-itu last-tick-start-itu)
  (assert (flokkr-p flok))
  (bifrost:with-bifrost
      (loop do (let ((tick-start-itu (get-internal-real-time)))
                 (unless last-tick-start-itu
                   (setf flok-start-itu tick-start-itu
                         last-tick-start-itu tick-start-itu))

                 ;; (1) start tick: update timers & compute any global delay
                 (let* ((*flokkr-elapsed-seconds* (seconds-between-itu tick-start-itu flok-start-itu))
                        (*flokkr-step-seconds* (seconds-between-itu tick-start-itu last-tick-start-itu))
                        (global-delay-seconds (funcall (flokkr-start-tick flok))))
                   (declare (special *flokkr-elapsed-seconds* *flokkr-step-seconds*))

                   ;; (2) apply global delay, if there is any
                   (when (plusp global-delay-seconds)
                     (funcall (flokkr-add-global-delay flok) global-delay-seconds))

                   ;; (3) execute activated clauses & rescheduling logic
                   (bifrost:rune-read-no-hang)
                   (let ((*flokkr-tick-input-matched-p*))
                     (declare (special *flokkr-tick-input-matched-p*))
                     (funcall (flokkr-execute-clauses flok) tick-start-itu))

                   ;; (4) compute how long to wait
                   ;; (5) if appropriate, idle in an interuptable way
                   (setf last-tick-start-itu tick-start-itu)
                   (unless (bifrost:rune-listen) ; if there is input, skip waiting

                     ;; if there is no input, then see how long to wait
                     (let ((wait (funcall (flokkr-compute-wait flok))))
                       ;; WAIT must be an number of seconds or NIL
                       (assert (or (not wait)
                                   (numberp wait)))
                       (if bifrost:*bifrost-tty-p*
                           ;; we're inside a Unix-like terminal emulator, so we can react instantly
                           ;; to user input
                           (sb-sys:wait-until-fd-usable bifrost:*bifrost-tty-p* :input wait)
                           
                           ;; we're outside of a Unix-like terminal emulator, in read-debug mode
                           ;; so fall back on inefficient polling :-(
                           (sleep (if wait
                                       (min wait 0.02)
                                       0.02))))))))))

(defmacro flokkr (&body clauses)
  `(block flokkr
     (flokkr-run (subflokkr ,@clauses))))
                   
                         
;;;;;;;;;;;;;;;;;;;;;;;

                      
;; defmacro subflokkr (&body clauses)
;;   let ,⁠@timers, subflokkrs
;;     (make-flokkr
;;       :has-input-p ??
;;       :tick-start (lambda (elapsed-seconds &aux (enforce-global-delay 0))
;;                       ,@clauses/
;;                        ;; timer
;;                         when timer
;;                           (decf timer elapsed)
;;                         when enforce-cooloff
;;                           (decf enforce-cooloff elapsed)
;;                           (when (and (plusp cooloff) timer (not (plusp timer)))
;;                             (unless (>= global-delay cooloff)
;;                               (setf enforce-global-delay cooloff)))
;;                          ;; subflokkr
;;                          (let ((subflokkr-delay (funcall (flokkr-start-tick sf) elapsed-seconds)))
;;                             (unless (>= global-delay subflokkr-delay)
;;                               (setf global-delay subflokkr-delay)))
;;                         global-delay)
;;         :add-global-delay (lambda (global-delay-seconds)
;;                             ,@clauses
;;                                ;; timer
;;                                when timer (incf timer global-delay-seconds)
;;                                (funcall (subflokkr-add-global-delay sf) global-delay-seconds))
;;         :execute-clauses (lambda (tick-start-itu &aux activated-p)
;;                              (declare (ignorable tick-start-itu))
;;                              ,@clauses
;;                                ;; timer
;;                                (when (and timer (not (plusp timer)))
;;                                  ,@body
;;                                  (setf activated-p t)
;;                                  ;; simple timer
;;                                  (when timer
;;                                    (setf timer ,form)
;;                                    ;; when enforce
;;                                    (setf enforce (+ ,form (/ (- (itu-time tick-start-itu)))
;;                                                             itu)
;;                                   )
;;                                  ;; drift
;;                                  (when timer
;;                                     (setf timer (+ ,form (/ (- (itu-time tick-start-itu)))
;;                                                             itu)))
;;                              ;; subflokkr
;;                              (setf activated-p ;; if percolate
;;                                    (or (funcall (subflokkr (subflokkr-execute tick-start-itu)))
;;                                                  activated-p))
;;                              ;; also
;;                              (when activated-p ,@body))
;;         :compute-wait (lambda (&aux next-wait)
;;                               ,@clauses
;;                                 ;; timer
;;                                 (when (or (not next-wait)
;;                                           (and timer (>= next-wait timer)))
;;                                    (setf next-wait timer))
;;                                 ;; subflokkr
;;                                 (let ((sf (funcall (flokkr-compute-next-wait sf))))
;;                                    (when (or (not next-wait)
;;                                               (and next-wait (>= next-wait timer)))
;;                                      (setf next-wait timer)))
;;                                 next-wait))





;;;;;;;;;;;;;;

;; (defvar *flokkr-input-read-flag* nil)

;; (defmacro %flokkr (&body clauses)
;;   (let ((start-now (gensym "flokkr-start-now-"))
;;         (activated (gensym "flokkr-activated-"))
;;         (input-matched (gensym "flokkr-input-matched-"))
;;         (global-run-timer (gensym "flokkr-run-global-wait-"))
;;         lexical-state
;;         body-forms
;;         global-scheduler-forms)
;;     (dolist (c clauses)
;;       (case (first c)
;;         (:input (push `(progn
;;                          (unless *flokkr-input-read-flag*
;;                            (bifrost:rune-read-no-hang)
;;                            (setf *flokkr-input-read-flag* t))
;;                          (when bifrost:*rune*
;;                            (unless ,input-matched
;;                              (bifrost:rune-case bifrost:*rune*
;;                                ,@(mapcar (lambda (in-case)
;;                                            `(,@in-case
;;                                              (setf ,activated t
;;                                                    ,input-matched t)))
;;                                          (rest c))))))
;;                       body-forms))
;;         (:also (push `(when ,activated
;;                         ,@(rest c))
;;                      body-forms))
;;         (:subflokkr
;;          (let ((subflokkr (gensym "flokkr-"))
;;                (subtimer (gensym "subflokkr-timer-")))
;;            (push `(,subflokkr ,(second c))
;;                  lexical-state)
;;            (push `(,subtimer ,start-now)
;;                  lexical-state)
;;            (push `(progn
;;                     (setq ,subtimer (funcall ,subflokkr))
;;                     ;; subflokkr THUNK must return an ITU time or NIL
;;                     (assert (or (not ,subtimer)
;;                                 (numberp ,subtimer)))
;;                     (when ,subtimer
;;                       (setf ,activated t)))
;;                  body-forms)
;;            (push `(when ,subtimer
;;                     (setf ,global-run-timer
;;                           (if ,global-run-timer
;;                               (min ,subtimer ,global-run-timer)
;;                               ,subtimer)))
;;                   global-scheduler-forms)))
;;         (otherwise
;;          (multiple-value-bind (%c timer) (%get-timer-name c)
;;            (multiple-value-bind (%c init) (%get-initial-wait %c)
;;              (multiple-value-bind (%c rescheduler) (%get-rescheduler %c timer)
;;                (case (first %c)
;;                  (:do
;;                   (push `(,timer (add-itu-seconds ,init ,start-now))
;;                         lexical-state)
;;                   (push `(when (itu-elapsed-p ,timer)
;;                            (setf ,activated t)
;;                            ,@(rest %c)
;;                            ,rescheduler)
;;                            body-forms)
;;                   (push `(when ,timer
;;                            (setf ,global-run-timer
;;                                  (if ,global-run-timer
;;                                      (min ,timer ,global-run-timer)
;;                                      ,timer)))
;;                         global-scheduler-forms))
;;                  (otherwise (error "FLOKKR clause not recognized as :DO, :INPUT, :ALSO, or :SUBFLOKKR form: ~A" c)))))))))
;;     `(let* ((,start-now (get-internal-real-time))
;;             ,@(reverse lexical-state))
;;        (lambda ()
;;          (let (,activated
;;                ,input-matched
;;                ,global-run-timer)
;;            (declare (ignorable ,activated ,input-matched))
;;            (setf ,start-now (get-internal-real-time))
;;            ,@(reverse body-forms)
;;            ,@(reverse global-scheduler-forms)
;;            (if (and *flokkr-input-read-flag*
;;                     (bifrost:rune-listen))
;;                ,start-now
;;                ,global-run-timer))))))



;; core runtime

;; (defun flokkr-run (thunk)
;;   "Main event loop: call thunk, wait for duration or input, repeat forever"
;;   (let ((global-run-timer (get-internal-real-time)))
;;     (bifrost:with-bifrost
;;       (loop
;;         do (let ((*flokkr-input-read-flag* *flokkr-input-read-flag*))
;;              (declare (special *flokkr-input-read-flag*))
;;              (setq global-run-timer (funcall thunk))
;; ;;             (format bifrost:*bifrost-io* "~%grt=~A irf=~A" global-run-timer *flokkr-input-read-flag*)
             
;;              ;; THUNK must return an itu time or NIL
;;              (assert (or (not global-run-timer)
;;                          (numberp global-run-timer)))

;;              (if *flokkr-input-read-flag*

;;                  ;; there is an :INPUT clause inside of THUNK
;;                  ;; if there is no input available, then until next input, up to DURATION
;;                  (when (or (not global-run-timer)
;;                            (plusp global-run-timer))
;;                    (if bifrost:*bifrost-tty-p*

;;                        ;; we're inside a Unix-like terminal emulator, so we can react instantly
;;                        ;; to user input
;;                        (sb-sys:wait-until-fd-usable bifrost:*bifrost-tty-p*
;;                                                     :input (let ((seconds (seconds-until-itu global-run-timer)))
;;                                                              (when (plusp seconds)
;;                                                                seconds)))

;;                        ;; we're outside of a Unix-like terminal emulator, in read-debug mode
;;                        ;; so fall back on inefficient polling :-(
;;                        (let ((default-input-polling-timer (add-itu-seconds 0.02)))
;;                          (sleep-until-itu (if global-run-timer
;;                                               (min global-run-timer
;;                                                    default-input-polling-timer)
;;                                               default-input-polling-timer)))))

;;                  ;; there is no :INPUT clause inside of THUNK
;;                  ;; if there are any active timers, keep going
;;                  ;; if not, then exit
;;                  (if global-run-timer
;;                      (sleep-until-itu global-run-timer)
;;                      (return-from flokkr-run))))))))

;; ;; main API entrypoint

;; (defmacro flokkr (&body clauses)
;;   `(block flokkr
;;      (flokkr-run (%flokkr ,@clauses))))

;; (defmacro subflokkr (&body clauses)
;;   `(%flokkr (block subflokkr
;;               ,@clauses)))
