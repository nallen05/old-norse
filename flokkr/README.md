
# Problem Statement

Terminal UI applications require concurrency: different screen components need to be able to 
update at different timings (eg: a CPU monitoring graph updatin at 10hz & a status panel updating 
at 1hz after 1 second initialization period), while simultaneously also providing immediate 
responsiveness to user input. However, terminal IO itself is single threaded.

# FLOKKR

FLOKKR is a cooperative multitasking library for Common Lisp, purpose-built for building 
interactive terminal UI applications using BIFROST. It is part of the OLD-NORSE Terminal Toolkit.

FLOKKR is implementation-dependent on SBCL.

# Design Philosophy

All timing logic visible in one place

```lisp
;; update CPU graph at 10 Hz
;; after 1 second, also update status panel at 1 Hz
;; if either changed, update that section of the screen to reflect
(flokkr
  (:do (update-cpu-graph) :reschedule 0.1)
  (:after 1 :do (update-status-panel) :reschedule 1)
  (:also (render-dashboard)))
```

Immediate reaction to user input

```lisp
;; hit +/- key to zoom in/out, or q/esc to exit
(flokkr
  (:do (update-cpu-graph) :reschedule 0.1)
  (:after 1 :do (update-status-panel) :reschedule 1)
  (:input
    (#\+ (user-zoom 1))
    (#\- (user-zoom -1))
    ((#\q #\esc) (return-from flokkr)))
  (:also (render-dashboard)))
```

Enable composability (while maintaining traceability)
```lisp
(defun move-enemies (gameboard)
  (subflokkr
     (:do (move-fast-enemies gameboard) :reschedule 0.05))
     (:do (move-slow-enemies gameboard) :reschedule 0.2)))

(defun run-game ()
  (flokkr
    (let ((b (make-gameboard)))
      (:subflokkr (move-enemies b))
      ;; ...other game logic...
      (:also (render-screen)))))
```


# MAIN API

`FLOKKR (&rest clauses)`
A macro. Endlessly runs CLAUSES. Use `(RETURN-FROM FLOKKR)` to escape. 

Clauses are defined using a keyword mini-language (inspired by the LOOP macro):

## Basic timer clauses

    ([:after INIT] :do FORMS* [:reschedule SECONDS || :reschedule-dynamic])

 - :AFTER INIT - Initial delay (optional, default 0)
 - :DO FORMS - Body forms (implicit PROGN, multiple forms can follow)
 - :RESCHEDULE SECONDS - SECONDS is evaluated once. Repeat at that interval. If SECONDS is NIL,
   then don’t repeat.
 - :RESCHEDULE-DYNAMIC - the last form of FORMS should return seconds (to reschedule),
   or NIL to stop

Examples:

    (:after 5.0 :do (init))                   ; One-shot after 5s
    (:after 5.0 :do (update) :reschedule 0.5) ; Delay then repeat
    (:do (update) :reschedule 1.0)             Repeat every 1s
    (:do (fancy) :reschedule-dynamic) ; dynamic interval, determined by the return value of FANCY



## Input handling

    (:input CASES*)

:INPUT runs whenever BIFROST:RUNE-READ-NO-HANG detects terminal input. 
- CASES are given to BIFROST:RUNE-CASE.
- once any case is successfully triggered by BIFROST:RUNE-CASE, then no other INPUT will run

# the :also keyword

    ([:also] FORMS*)

:ALSO runs FORMS if a flokkr clause *above* it was triggered in the same tick.
 - :ALSO is unaware of what happens below it.
 - :INPUT clauses only trigger :ALSO when a case actually matches. So if :INPUT runs but doesn’t
   match anything specific, that *won’t* cause :ALSO to run.

Example:
```lis;
(flokkr
  (:do (update-state-machine-1) :reschedule 0.5)
  (:do (update-state-machine-2) :reschedule 1)
  (:also (render-screen))) ;; whenever either of the above happens, render the screen
```

## Named timers

The :WITH-NAMED-TIMER keyword allows you to expose the name of a timer, so that it can be 
delayed/accelerated/cancelled/rescheduled by other clauses within the same FLOKKR/SUBFLOKKR 
form.

Example:

```lisp
(defparameter *timer* 0)

(flokkr
  ;; every 1 second, advance the timer & update the screen
  (:with-named-timer timer
   :after 1 :do (incf *timer*) (render-stopwatch)
   :reschedule 1)
  (:input
    ;; hit spacebar key to pause/unpause the timer
     (#\space (flokkr-reschedule timer
                                 (if stopwatch 
                                     nil
                                     1)))))
```
Macros for manipulating timers:

`FLOKKER-RESCHEDULE(timer seconds-or-nil)`
A macro. Used to reschedule a named timer to a new ITU time. Positive numbers set the timer that
many seconds in the future. 
 - Zero (or a negative number) is treated as now, making the timer ready to fire.
 - If SECONDS-OR-NIL is NIL, it turns the timer off, preventing it from firing.

`FLOKKER-DELAY(timer seconds-or-nil)`
A macro. Used to delay or accelerate an active timer. 
 - Positive numbers delay it by that many seconds. Negative numbers accelerate it back that many 
   seconds. If it is pulled back to the current time or a time in the past, it becomes ready to 
   fire 
 - If SECONDS-OR-NIL is NIL, it turns the timer off, preventing it from firing again.
 - If TIMER was already NIL, then the timer stays off. It won’t be turned back on.



# Composing subflokkrs

`SUBFLOKKR (&rest clauses)`
A macro. Used to define subflokkrs that can be run by FLOKKR-MAIN (or by other subflokkrs) via the
:SUBFLOKKR keyword.

Useful for defining the behavior of widgets or state machines separately, then composing them 
later.

Example: 

```lisp
(defun player-notifications-widget (user)
  (subflokkr
    (:do (update-player-health-notifications user) :reschedule 0.1))
    (:do (update-system-message-notifications user) :reschedule 1)))

(flokkr-main
  (:subflokkr player-notifications-widget user)
  (:also (render-screen))

```


## Development roadmap

### bug?

in :RESCHEDULE SECONDS, SECONDS is currently evaluated every time the clause is triggered.
Verify if this is what we want.


### more friendly behavior when called within SLIME/EMACS (BIFROST)

When click-testing flokkr from within SLIME/EMACS, you have to hit enter to force IO. This is 
unintuitive/unfriendly to new users.

Fix it with a well-placed FORCE-OUTPUT. But carefully consider impacts to the BIFROST debugging 
mode API.

### coordinating GC pauses

Enable using FLOKKR to accept hints to signal ideal times for gc pauses to run. Exact syntax TBD.

### ability for :INPUT clauses to yield

Ability for an input clause to decide NOT to handle a matched iput.

## Development roadmap (icebox)

### debouncing

Debouncing function to ensure something doesn't happen too frequently. Exact syntax TBD.

I'm not sure we need additional logic for this.
