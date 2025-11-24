



# Old Norse: Terminal Toolkit

OLD-NORSE is collection of Common Lisp libraries for building interactive terminal UI applications
that:
1. are mouse-driven & highly responsive
2. have rich, grid-based terminal graphics, with smooth animation
3. work over remote connection, via SSH or [TTYD](https://tsl0922.github.io/ttyd/) for browser-based deployment

You can build:

- **User Dashboards** - System monitoring, log viewers, build status
- **Text-based Games** - Roguelikes, puzzle games, text adventures
- **Data Visualization** - Charts, tables, real-time data feeds


## Libraries

### [Bifrost](bifrost/) 🌈
Low-level terminal I/O and escape sequence handling
- Lisp API for reading from & controlling the terminal
- Low-level support for mouse event tracking
- Uses raw I/O for faster performance (includes debugging mode to troubleshoot terminal apps
  within SLIME/EMACS or other REPL)


### [Skald](skald/)
High-level terminal UI and animation framework
- Treat blocks of ASCII and unicode text as sprites
- Supports features like grid-based positioning/layout, colors, transparancy, emojis, etc
- Optimizes screen updates to minimizes flicker when redrawing


### [Flokkr](flokkr/)
Cooperative multitasking library, purpose built for BIFROST applications
- Manage complex timing loops
- Respond instantly to user input
- Define widget & state-machine behaviors seperately then compose via subflockkrs


### [Meadhorn](meadhorn/)
Very simple debugging utility. 
- The simplest debugging tool is a print statement. MD is like FORMAT except that it broadcasts
  the print statement output to a Unix socket.
- Read the output with [netcat](https://en.wikipedia.org/wiki/Netcat) to debug without disrupting the terminal UI


### Old Norse
You can load all of these libraries via `(require :old-norse)


## Quick Start

**Run these in the terminal, not SLIME/EMACS**

Write to the screen

```lisp
(bifrost:with-rune-raw-io  ; low-level setup
  (skald:skald-init)       ; clear the screen
  (skald:skald-draw ()     ; bundle set of updates the screen
    (skald:sprite (3 3     ; draw an ASCII sprite
                   :foreground :cyan)
      "╔═══════════════╗"
      "║ Hello, world! ║"
      "╚═══════════════╝")))
```


Fast animation that follows mouse movement
```lisp
(bifrost:with-rune-raw-io                  ; low-level setup
  (skald:skald-init)                       ; clear the screen
  (bifrost:with-mouse-tracking (1003)      ; track mouse hover events
    (bifrost:with-cbox t
      (flokkr:flokkr
        (:input                            ; listen for mouse events
          (:mouse-click-left (return))     ; on left click, exit
          (:mouse-move                     ; on mouse movement, reposition
            (skald:skald-draw ()
              (skald:sprite ((second rune) 
                             (third rune)
                             :foreground :cyan)
                "╔═══════════════╗"
                "║ Hello, world! ║"
                "╚═══════════════╝"))))))))
```


Mouse movement tracking + seperate simultaneous animation loop timing

```lisp
(bifrost:with-rune-raw-io                      ; low-level setup
  (skald:skald-init)                           ; clear the screen
  (bifrost:with-mouse-tracking (1003)          ; track mouse hover events
    (bifrost:with-cbox t
      (let ((seconds 0)
            (row 1)
            (col 1))
        (flokkr:flokkr
          (:after 1 :do (incf counter)         ; every second, advance the timer
           :reschedule 1)
          (:input
            (:mouse-click-left (return))       ; on left click, exit
            (:mouse-move                       ; on mouse movement, reposition
             (setf row (second *rune*)
                   col (third *rune*))))
          (:also (skald:skald-draw ()          ; if either of the above happened, re-render
                   (skald:span (row col :foreground cyan)
                     (format nil "~a seconds" seconds))))))))
```

# ## Design pillars

## (1) grid-based terminal graphics

Treat blocks of text as layerable sprites. 
 - Support transparant character.
 - Currently supports ASCII, UNICODE, & EMOJI. In the future, we will also add support for [sixel](https://en.wikipedia.org/wiki/Sixel) 
   graphics, snapping sixel sprites to the same terminal grid.

## (2) prioritize speed & responsiveness

Design goals (assume standard terminal screen size):
 * >60fps animation
 * Screen update within 16ms of user input (not counting network latency)

Based on our observation, this can be achieved by managing the following bottlenecks:
1. Minimizing the size of terminal screen updates - SKALD does this under the hood via 
   update/display buffers
2. Reacy immediately to user input - FLOKKR provides this, while simultaneously managing dynamic 
   animation and state machine and timings.
3. Strategic scheduling of GC pauses -  Currently must be managed by the user. But there is a
   roadmap feature planned to enable FLOKKR to coordinate better/worse times for gc.
   (Additionally, there are also planned roadmap features to reduce GC pressure created by
   SKALD/BIFROST itself.)
4. Slow DB queries - must be managed by the user. 

## (3) Develop in an hour. Deploy anywhere.

Full-featured, mouse-driven terminal UI applications should work remotely via SSH or
browser-based (TTYD). In the future, we will also add enhanced support for mobile deployment 
(swiping, etc).


## (4) high locality code structure

If not structured correctly, even the simplest Terminal UI application can grow into a complicated
mess of spaghetti code. The “OLD-NORSE way” is to deal with this by prioritizing locality, putting
related logic together.

1. SKALD makes it possible to define a single function that draws the ENTIRE screen, and then 
   liberally call it whenever there is a state update that should be reflected on the screen. 
   Under the hood, SKALD uses a system of buffers to track the state of the screen & only update
   regions of the terminal screen that have actually changed since the last rendering. This 
   pattern tends to DRASTICALLY simplify program structure.

2. FLOKKR makes it possible to view all timing logic in one place, making it easier to reason 
   about dynamic timing frequencies and interactive behaviors. Modular composability is possible
   via SUBFLOKKR, but within rigid constraints of chaining via :SUBFLOKKR help to prevent hidden
   scheduling issues.

## Recommended conventions

We have found the following prefix naming convention to be useful to use with this library:

```lisp 
;;   [r]-row        row coordinate on the terminal grid (sometimes called Y)
;;   [c]-column     column coordinate on the terminal grid (sometimes called X)
;;   [rc]-cons      a cons of (ROW . COLUMN). Sometimes called a "point"
;;   [n]-ticks      number of ticks/frames for something to run (eg for an animation)
;;   [%]-progress   for tracking transition from 0.0 to 1.0 (state machine or animation)
;;   [d]-duration   duration of seconds (not ITU) to wait
;;   [t]-time       an ITU time, like the one returned by GET-INTERNAL-REAL-TIME
```

## Requirements
- Terminal with XTERM mouse tracking (iTerm, Xterm, etc.)
- Monospaced font
- BIFROST/SKALD are portable. Currently, FLOKKR & MEADHORN require SBCL.

## Status

v0.0 - Core API subject to change

## Alternatives

[cl-tuition](https://github.com/atgreen/cl-tuition)

## License

MIT
