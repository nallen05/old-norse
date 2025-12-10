


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

;; LOOP-inspired keyword mini-language

(defstruct flokkr
  reads-input-p     ;; (0) does this flokkr look for input from the terminal?
  advance-timers    ;; (1) start tick: update timers & compute any global delay
  add-global-delay  ;; (2) apply global delay, if there is any
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

(defun %extract-enforce-cooloff (clause &aux enforce-cooloff-form enforce-cooloff-seen-p on-enforce)
  "clause -> stripped-clause, enforce-cooloff-form, enforce-cooloff-seen-p"
  (labels ((rfn (_)
             (when _
               (destructuring-bind (1st . rest) _
                 (case 1st
                   (:enforce-cooloff
                     (if enforce-cooloff-seen-p
                         (error "FLOKKR: multiple :ENFORCE-COOLOFF forms seen in the same clause (~a)" clause)
                         (progn
                           (setf enforce-cooloff-form (car rest)
                                 enforce-cooloff-seen-p t)
                           (rfn (cdr rest)))))
                   (:on-enforce
                    (setf on-enforce (car rest))
                    (rfn (cdr rest)))
                   (otherwise (cons 1st (rfn rest))))))))
    (values (rfn clause)
            enforce-cooloff-form
            enforce-cooloff-seen-p
            on-enforce)))

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
                          reschedule-form (car rest))
                    nil)
                   (t (cons 1st (rfn rest))))))))
    (values (rfn clause)
            reschedule-form
            reschedule-type)))

(defmacro subflokkr (&body clauses)
  (let ((tick-start-itu (gensym "flokkr-tick-start-itu-"))
        (global-delay-seconds (gensym "flokkr-global-delay-"))
        (on-enforce (gensym "flokkr-on-enforce-global-delay-"))
        (activated (gensym "flokkr-activated-"))
        (next-wait (gensym "flokkr-next-wait-"))
        lexical-state
        reads-input-p
        subflokkrs-list
        advance-timers-body
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
                      execute-body)
                 (setf reads-input-p t))
        (:also (push `(when ,activated
                        ,@(rest c))
                     execute-body))
        (:subflokkr
          (destructuring-bind (form &key percolate)
              (rest c)
            (let ((subflokkr (gensym "subflokkr-"))
                  (subflokkr-ret (gensym "subflokkr-returned-value-")))
              (push `(,subflokkr ,form)
                    lexical-state)
              (push subflokkr subflokkrs-list)
              (push `(let ((,subflokkr-ret (funcall (flokkr-advance-timers ,subflokkr))))
                       (when (> ,subflokkr-ret ,global-delay-seconds )
                         (setf ,global-delay-seconds ,subflokkr-ret)))
                    advance-timers-body)
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
             (multiple-value-bind (%c cooloff-form cooloff-seen-p on-enforce-form)
                 (%extract-enforce-cooloff %c)
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
                                            (setf ,global-delay-seconds ,cooloff
                                                  ,on-enforce ,on-enforce-form)))))
                                   `(when ,timer
                                      (decf ,timer *flokkr-step-seconds*))))
                              (:drift
                               `(when ,timer
                                  (decf ,timer *flokkr-step-seconds*))))
                            advance-timers-body))
                     (push `(when ,timer
                              (incf ,timer ,global-delay-seconds))
                           add-global-delay-body)
                     (push `(when (and ,timer (not (plusp ,timer)))
                              ,@(rest %c)
                              (setf ,activated t)
                              ,@(ecase scheduler-type
                                  (:schedule
;;                                   `((setf ,timer ,scheduler-form)))
                                   (let ((next (gensym "flokkr-scheduler-next-")))
                                     `((let ((,next ,scheduler-form))
                                         (if ,next
                                             (incf ,timer ,next)
                                             (setf ,timer nil))))))
                                  (:drift
                                   `((setf ,timer
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
    `(let (,@(nreverse lexical-state))
       (make-flokkr
        ;; (0) does this flokkr look for input from the terminal?
        :reads-input-p (or ,(when reads-input-p
                              t)
                           ,@(mapcar (lambda (sf) `(flokkr-reads-input-p ,sf))
                                     subflokkrs-list))
        ;; (1) start tick: update timers & compute any global delay
        :advance-timers (lambda (&aux (,global-delay-seconds 0) ,on-enforce)
                          ,@(nreverse advance-timers-body)
                          (when ,on-enforce
                            (funcall ,on-enforce ,global-delay-seconds))
                          ,global-delay-seconds)
        ;; (2) apply global delay, if there is any
        :add-global-delay (lambda (,global-delay-seconds)
                            ,@(nreverse add-global-delay-body))
        ;; (3) execute activated clauses & rescheduling logic
        :execute-clauses (lambda (,tick-start-itu &aux ,activated)
                           (declare (ignorable ,tick-start-itu))
                           ,@(nreverse execute-body)
                           ,activated) ;; return value not used,
                                       ;; it's just to stop compiler error of ACTIVATED being ignored if there is no :ALSO
        ;; (4) compute how long to wait
        :compute-wait (lambda (&aux ,next-wait)
                        ,@(nreverse compute-wait-body)
                        ,next-wait)))))

(defun %flokkr-run (flok &aux flok-start-itu last-tick-start-itu)
  (loop do (let ((tick-start-itu (get-internal-real-time)))
             (unless flok-start-itu
               (setf flok-start-itu tick-start-itu
                     last-tick-start-itu tick-start-itu))

             ;; (0) does this flokkr look for input from the terminal?
             (when (flokkr-reads-input-p flok)
               (bifrost:rune-read-no-hang))

             ;; (1) start tick: update timers & compute any global delay
             (let* ((*flokkr-elapsed-seconds* (seconds-between-itu tick-start-itu flok-start-itu))
                    (*flokkr-step-seconds* (seconds-between-itu tick-start-itu last-tick-start-itu))
                    (global-delay-seconds (if (plusp *flokkr-step-seconds*)
                                              (funcall (flokkr-advance-timers flok))
                                              0)))
               (declare (special *flokkr-elapsed-seconds* *flokkr-step-seconds*))

               ;; (2) apply global delay, if there is any
               (when (plusp global-delay-seconds)
                 (funcall (flokkr-add-global-delay flok) global-delay-seconds))

               ;; (3) execute activated clauses & rescheduling logic
               (let (*flokkr-tick-input-matched-p*)
                 (declare (special *flokkr-tick-input-matched-p*))
                 (funcall (flokkr-execute-clauses flok) tick-start-itu))

               ;; (4) compute how long to wait
               ;; (5) if appropriate, idle in an interuptable way
               (setf last-tick-start-itu tick-start-itu)
               (if (flokkr-reads-input-p flok)

                   ;; this flokkr looks for input, so only wait if there is no input
                   (unless (bifrost:rune-listen)
                     (let ((wait (funcall (flokkr-compute-wait flok))))
                       (assert (or (not wait)
                                   (numberp wait)))
                       (if bifrost:*bifrost-tty-p*
                           ;; we're inside a Unix-like terminal emulator, so we can react instantly
                           ;; to user input
                           (sb-sys:wait-until-fd-usable bifrost:*bifrost-tty-p* :input wait)
                           
                           ;; we're outside of a Unix-like terminal emulator, in read-debug mode
                           ;; so fall back on inefficient polling :-(
                           (if wait
                               (let* ((now (get-internal-real-time))
                                      (stop (+ now (floor (* wait internal-time-units-per-second)))))
                                 (loop until (or (bifrost:rune-listen)
                                                 (>= (get-internal-real-time) stop))
                                       do (sleep 0.02)))
                               (loop until (bifrost:rune-listen)
                                     do (sleep 0.02))))))
                   ;; this flokkr does not look for input, so just wait unconditionally
                   (let ((wait (funcall (flokkr-compute-wait flok))))
                     (if wait
                         (sleep wait)

                         ;; there are no timers & we're not waiting for input, so just exit
                         (return-from %flokkr-run))))))))

(defun flokkr-run (flok)
  (assert (flokkr-p flok))
  (if (flokkr-reads-input-p flok)
      (bifrost:with-bifrost
        (%flokkr-run flok))
      (%flokkr-run flok)))

(defmacro flokkr (&body clauses)
  `(block flokkr
     (flokkr-run (subflokkr ,@clauses))))
