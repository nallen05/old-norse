
# Problem Statement

Terminal UI applications require concurrency: different screen components need to be able to update at different timings (eg: a CPU monitoring graph updating at 10hz & a status panel updating at 1hz after 1 second initialization period), while simultaneously also providing immediate responsiveness to user input. However, terminal IO itself is single threaded.

# FLOKKR

Flokkr is a concurrency library for Common Lisp, purpose-built for building interactive terminal UI applications using skald/bifrost. 
- Flokkr is built around a mini-DSL (inspired by the LOOP macro)
- Flokkr is based on a cooperative multitasking model. But there is a plan to add an additional lightweight async feature, based on SBCL threads, to handle slow DB queries & cloud API calls outside of the main loop.
- Flokkr is implementation-dependent on SBCL.

Flokkr is part of the Old Norse Terminal Toolkit.

# Quickstart

## Example: two syncronized timers

```lisp
(let ((10hz 0)
      (4hz 0))
  (format t "~%elapse 10hz  4hz     step~%")
  (flokkr:flokkr
    (:do (incf 10hz) :schedule 0.1)
    (:after 0.25 :do (incf 4hz) :repeat)
    (:also (format t "~&~7,3F ~4D ~4D ~8,4F"
                   flokkr:*flokkr-elapsed-seconds*
                   10hz
                   4hz
                   flokkr:*flokkr-step-seconds*))))
```

Running the above will start endlessly printing a sequence like:
```
elapse 10hz  4hz     step
  0.000    1    0   0.0000
  0.101    2    0   0.1007
  0.205    3    0   0.1046
  0.254    3    1   0.0483
  0.301    4    1   0.0472
  0.405    5    1   0.1043
  0.505    6    2   0.1002
  0.603    7    2   0.0972
  0.702    8    2   0.0993
  0.754    8    3   0.0526
  0.804    9    3   0.0500
  0.900   10    3   0.0960
  1.000   11    4   0.1000
  1.104   12    4   0.1039
  1.203   13    4   0.0988
  1.255   13    5   0.0522
  1.305   14    5   0.0502
  1.405   15    5   0.1000
  1.505   16    6   0.1000
  1.600   17    6   0.0950
```
...and so on, until you C-c to quit
 - "elapsed" is how many seconds have gone by since FLOKKR started running
 - "step" is how many seconds have gony by since the last tick
 - "10hz" & "4hz" count cycles at that speed
 
You may notice some small jitter (eg: the 10hz timer firing at 0.754 seconds instead of 0.75 seconds). Small jitter happens due to things like from OS scheduler latency, garbage collection, & overhead in entering and exiting the wait syscall. It is offset by the schedular, so it does not compound/accumulate across multiple ticks.


# Example: A timer + user input

*Run this example in the terminal, not SLIME/EMACS*

Hit buttons on the keyboard or 

```lisp
(let ((1hz 0)
      (input 0)
      last-input)
  (format t "~%elapse   1hz input last-input")
  (flokkr:flokkr
    (:do (incf 1hz) :schedule 1)
    (:input
      ((#\q #\esc) (return-from flokkr:flokkr)) ;; hit q or Escape to exit
      (otherwise (incf input) (setf last-input bifrost:*rune*)))
    (:also (format t "~&~6,2F ~5D ~5D ~s~%"
                   flokkr:*flokkr-elapsed-seconds*
                   1hz
                   input
                   last-input)
            (force-output))))
```

# Flokkr design philosophy

1. Dedicated to making interactive TUIs
  - tightly coupled with BIFROST, so don't read directly from `SB-SYS:*TTY*` while FLOKKR is looking for input
2. Speed: immediately respond to user input; correctly juggle multiple timers; avoid polling
3. Precision & predictability: by default, all timers syncronize via a global schedule. So you can depend on them interesecting at recurring frequences.
4. All timing logic visible in one place to make it easier to understand & reason about interactive timing behaviors. (Encourages Old Norse "high locality" code structure)
5. Enable composability: You can define widget behaviors seperately then compose them later, but within rigid constraints (:SUBFLOKKR) to enforce traceability and avoid hidden scheduling problems

# Understanding timer logic

## Basic timers

```lisp
(flokkr
  (:do (task1) :schedule 0.1)        ;; timer 1
  (:after 0.25 :do (task2) :repeat)) ;; timer 2
```

Each a timer defines its own time duration (expressed in seconds) between the start of the current tick & the start of a future tick when it should activate.


```
Tick N starts                             Scheduled Tick N+1 start
|                                         .
|                                         .
|                                         .
<--------- scheduled duration ------------>
```

FLOKKR keeps timers in sync with each other by scheduling based on tick-start to tick-start. Long running tasks cut into the idle cooloff period between tick execution ending & the next tick starting.

```
Tick N starts
|
|
+---- work (busy) ----+
                      |
                      +-- cooloff (idle)--+
                      .                   |
                      .                   |
                      .                   Tick N+1 starts
                      .                   .
<--------- scheduled duration ------------>
                      .                   .
                      .                   .
<----------- actual duration ------------->
                      .                   .
                      .                   .
                      <--- interuptable -->
```

During the idle cooloff period, when not busy, the app may be interupted by user input (:INPUT).

Thus:
- The actual duration between two scheduled ticks (start-to-start) should match the exact scheduled duration.
- When two timers are running simultaniously (eg: one repeating every 0.1 second & another every 0.25 seconds) they should intersect at predictable frequencies (eg: at 0.5, 1.0, 1.5, 2.0, etc...). This is ideal for SKALD screen updates (where you want to be very precise about when you update the screen) & game timings (eg: a timing puzzle).

## Use :DRIFT to enforce rigid cooloff, but it will breaking synronization with the global schedule

If you use :DRIFT (instead of :SCHEDULE or :AFTER/:REPEAT), then *cooloff* is kept consistent (not start-to-start duration). This causes the timings of sibling timers in the same FLOKKR form to diverge with each other due to small differences in how long it takes work to complete. This is ok for things like a background task that polls a rate limited API. But less ideal for things like game objects or connected UI widgets that need to be tightly in sync with each other.

```lisp
(flokkr
  (:do (background-task1) :drift 0.1)                 ;; timer 1
  (:after 0.25 :do (background-task2) :repeat-drift)) ;; timer 2
```


## Use :ENFORCE-COOLOFF to enforce hard cooloff without breaking synronization between timers

```lisp
(flokkr
  (:do (fast-update) :schedule 0.1)
  (:do (slow-update) :schedule 1)
  (:also (render-screen)
   :enforce-cooloff 0.06)) ;; every frame should display for least 0.06 seconds before moving on to the next one
```

Like :DRIFT, :ENFORCE-COOLOFF enforces cooloff (not duration). But unlike :DRIFT it goes to great length to keep long running timers in sync with the global schedule. If :ENFORCE-COOLOFF sees it will be violated, it applies a global delay to *every other timer* in the flokkr form to put the global schedule back in sync. During this "global delay" period all timers are idle, but the app is still free to be interupted by user input.

```
Tick N starts                       Scheduled Tick N+1 start
|                                   .
|                                   .
+---- slow work (busy) ----+        .
                           |        .
                           +----- enforced cooloff -----+
                           .        .                   |
                           .        .                   |
                           .        .                   Actual Tick N+1 start
                           .        .                   .
<------ scheduled duration --------->                   .
                           .        .                   .
                           .        .                   .
                           .        <--- global delay -->
                           .                            .
                           .                            .
<------------------ actual duration -------------------->
                           .                            .
                           .                            .
                           <--- interuptable by user --->
```



----------

# Lisp API

## `FLOKKR (&body clauses)`
A macro. The main entry point to the Flokkr API. 
- Runs CLAUSES. CLAUSES are are defined using a keyword mini-language (inspired by the LOOP macro).
- Exits if there are no active timers & or :INPUT clause. But usually you use `(RETURN-FROM FLOKKR)` to escape. 

## `SUBFLOKKR (&body clauses)`
A macro. Returns a subflokkr objet, to be imported and used within FLOKKR (or another SUBFLOKKR) via the :SUBFLOKKR keyword.
- CLAUSES are handled the same as FLOKKR

## `*FLOKKR-ELAPSED-SECONDS*`
## `*FLOKKR-STEP-SECONDS*`
These special variables are set within a FLOKKR form. They are exposed mostly for debugging/troubleshooting.
- `*FLOKKR-ELAPSED-SECONDS*`is bound to the number of seconds that have elasped since the FLOKKR started.
- `*FLOKKR-STEP-SECONDS*`is bound to the number of seconds that have elasped since the most recent tick.


# keyword mini-DSL

# Basic timer clauses

    ([:after SECONDS] :do FORMS* [:schedule SECONDS || :repeat])

 - :AFTER SECONDS - Initial delay (optional, default 0)
 - :DO FORMS - Body forms (implicit PROGN, multiple forms can follow)
 - :SCHEDULE SECONDS - Repeat at that interval. If SECONDS is NIL, then don’t repeat. Re-evaluted after each activation.
 - :REPEAT - Like :SCHEDULE, but reuses the form from :AFTER.

Examples:

    (:do (fancy) :schedule 1.0)              =; execute then repeat every 1 second
    (:after 5.0 :do (init))                 ; One-shot after 5s
    (:after 5.0 :do (update) :repeat)       ; Delay then repeat
    (:after 5.0 :do (update) :schedule 0.1) ; Delay then repeat at faster speed

## Input handling

    (:input CASES*)

:INPUT runs whenever bifrost detects terminal input. 
- CASES are handled by CASE, dispatching off of `BIFROST:*RUNE*`
- after the first time input is matched by CASE, then no other :INPUT will run. So pressing a key or clicking a button will only ever trigger one action.
- Note: FLOKKR calls WITH-BIFROST under the hood, so you are able to run FLOKKR outside of WITH-BIFROST. However, it's recommended good convention to wrap your entire program within WITH-BIFROST, including FLOKKR.

# the :also keyword

    ([:also] FORMS*)

:ALSO runs FORMS if a flokkr clause *above* it was activated in the same tick.
 - :ALSO is unaware of what happens below it.
 - :INPUT only triggers :ALSO when a the terminal input is actually matched. So if there is terminal input but :INPUT doesn’t match it, that *won’t* cause :ALSO to run.
 - :SUBFLOKKR activity doens't trigger :ALSO, *unless* :PERCOLATE is truthy.

Example:
```lisp
(flokkr
  (:do (update-state-machine-1) :reschedule 0.5)
  (:do (update-state-machine-2) :reschedule 1)
  (:also (render-screen))) ;; whenever either of the above happens, render the screen
```


## enforcing cooloffs

```lisp
(flokkr
  (:do (fast-update) :schedule 0.1)
  (:do (slow-update) :schedule 1)
  (:also (render-screen)
    :enforce-cooloff 0.06
    :on-enforce (lambda (delay) (log "~% slow animation (~a delay)" delay))))
    )
```


## background processing can drift
```lisp
(flokkr
  (:do (background-task1) :drift 0.1)                 ;; timer 1
  (:after 0.25 :do (background-task2) :repeat-drift)) ;; timer 2
```


## Named timers

The :WITH-NAMED-TIMER keyword allows you to expose the name of a timer, so that it can be delayed/accelerated/cancelled/rescheduled by other clauses within the same FLOKKR/SUBFLOKKR form. It works with :RESCHEDUE, :DRIFT, & :AFTER/:REPEAT

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
                                 (if timer
                                     nil
                                     *timer*)))))
```


:WITH-NAMED-COOLOFF is similar, but just for :ENFORCE-COOLOFF



# Composing subflokkrs

:PERCOLATE
:SUBFLOKKR-DRIFT

`SUBFLOKKR (&rest clauses)`
A macro. Used to define subflokkrs that can be run by FLOKKR-MAIN (or by other subflokkrs) via the :SUBFLOKKR keyword.

Useful for defining the behavior of widgets or state machines separately, then composing them later.

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



# Recommended conventions

## Glossary

Let's use the following terminology for consistency:
- "clause": a form given to the FLOKKR macro, which defines a single timing rule (timer logic + :DO, :INPUT, :ALSO, :SUBFLOKKR, etc)
- "tick": when FLOKKR wakes up (because a timer expired or there was terminal input) & checks every clause for potential activation.
- "activation": when a clause runs because its timer is expired or an :INPUT clause matches terminal input
- "frame": a tick becomes a frame if one of its activated clauses updates the TUI screen
- "step" the time in between the current & most recent tick (which may have been caused by the same timer, or different timer, or user input)
- "scheduled duration" the number of seconds beetween the start of the current tick & a subsequent tick when that specific timer is scheduled to run (which may not be the NEXT tick, there may be others in between)
- "cooloff" the number of seconds beetween when a clause finishes executing & the start of the NEXT timer-activated tick. During this time, the app is free to be interupted by user iput
- "drift" when a timer gets out of sync with the other timers because it's timer logic is rigidly enforcing a cooloff duration, in a way that does not take into account the time it takes to execute (see :DRIFT)
- "global delay" the amount of time that all timers are slowed down because of another timer using :ENFORCE-COOLOFF. When the app is globally delayed, it can still be interupted by user input.
- "total elapsed time" the number of seconds between FLOKKR being started & the current tick.

## Variable naming conventions

We have found using the following prefix naming conventions to be useful when structuring our own TUIs with Old Norse:

```lisp
;; <d>-duration-seconds    duration of seconds to wait (or that accured between events)
;; <%>-progress            for tracking transition from 0.0 to 1.0 (state machine or animation)
;; <n>-tick-count          number of ticks/frames for something to run (eg for an animation)
```
