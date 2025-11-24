



# Old Norse: Terminal Toolkit

Old Norse is collection of Common Lisp libraries for building fast, responsive Terminal UI (TUI)
applications that are mouse-driven and work remotely (via SSH, or browser-based via [TTYD](https://tsl0922.github.io/ttyd/))

Old Norse was originally created for rapidly prototyping games (roguelike RPG, 
strategy/simulation, idle/clicker, etc). But it's just as useful for developing quick internal 
tools (eg: system monitoring, log viewers, build status, etc) and interactive data visualizations
(charts, tables, real-time data feeds, etc). 

Old Norse a grid-based terminal graphics engine, with focus on UI speed/responsiveness & rapid
development/deployment.


## Libraries 

### Bifrost 🌈
[Bifrost](bifrost/) is a low-level utility for reading from & controlling the terminal
- Two-way mapping between ASCII escape sequences & s-expressions
- Raw I/O to bypass terminal read buffer (use debug mode to troubleshoot TUI within SLIME/EMACS)
- Low-level logic for mouse events and layerable click regions

### Flokkr
[Flokkr](flokkr/) is a cooperative multitasking library purpose built for building interactive
Terminal UI applications
- Manage timing loops via mini-DSL (inspired by the LOOP macro)
- Respond instantly to terminal input from user (without relying on polling)
- Define widget/object timing behaviors seperately, then compose via :SUBFLOCKKR

### Skald
[Skald](skald/) is a high-level terminal UI and animation framework
- Treat blocks of ASCII/unicode text as sprites (transparant char enables composite layering)
- Optimized to minimize flicker when redrawing the screen
- Features like grid-based positioning/layout, cropping, fill, colors, emojis, etc

### [Meadhorn](meadhorn/)
Meadhorm is a simple debugging utility. 
- Print statements are a simple, powerful debugging tool. But when developing terminal
  applications, they mess up the display.
- MEADHORN:MD is just like FORMAT except that it broadcasts output to a Unix socket. Read with
  [netcat](https://en.wikipedia.org/wiki/Netcat) to debug without disrupting the terminal UI.

### Old Norse
You can load all of these libraries via the umbrella package `(require :old-norse)`


## Quick Start

**Run these examples in the terminal, not SLIME/EMACS**

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


Mouse movement tracking + seperate simultaneous animation timing loop

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

Treat blocks of text as sprites.
 - Supports ASCII, UNICODE, & emoji (emoji treated as double-width characters)
 - foreground/background color
 - Composite layering enabled via transparant character.
 
In the future, we will also add support for [sixel](https://en.wikipedia.org/wiki/Sixel) graphics.
- This will allow animation & display of higher-resolution images (including larger text with
  non-monospaced font).
- However, the terminal grid will remain the only coordinate system. Sixel sprites will need to
  snap to the same grid.

## (2) Speed & responsiveness

Design goals:
 1. 60fps animation
   - assumes normal screen size
 2. Screen updates within 16ms of user input
   - if delpoyed over remote connection, assumes within same geographic region

Based on our observation, this can be achieved by managing the following bottlenecks:
1. Minimize the number of terminal grid cells redrawn per second  - This means eliminating all
   unecessary redrawing. SKALD does this under the hood by using update/display buffers to
   optimize screen updates.
2. Immediate user input reaction - FLOKKR provides this, while also simultaneously managing
   dynamic animation and state machine and timings.
3. When deploying remotely, keep in-region - must be managed by the user.
4. Strategic scheduling of GC pauses -  Currently must be managed by the user. But there is a
   plan to add a feature to FLOKKR to accept hints to coordinate better/worse times for gc pause.
   (Additionally, there is also a roadmap to reduce GC pressure created by SKALD/BIFROST 
   libraries themselves.)
5. Slow DB queries & cloud API calls - must be managed by the user. 

## (3) Locality

If not structured correctly, even the simplest Terminal UI application can grow into a complicated
mess of spaghetti code. The Old Norse way to deal with this is by prioritizing locality. In other
words, the TUI application code structure should put related logic close together.

1. JUST ONE FUNCTION TO RENDER THE ENTIRE SCREEN - SKALD is designed to enable you to define a
   single function to draw the entire screen, and then call it however frequently you want,
   relying on SKALD's low-level optimization to eliminate unecessay redrawing. SKALD-DRAW only
   updates the sections of the that have actually changed. In practice, this pattern of 
   application code structure tends to DRASTICALLY simplify & shorten programs.

2. JUST ONE STRUCTURE CONTROLING YOUR APP - FLOKKR makes it possible to view all timing logic &
   input reaction logic in one place, making it easier to reason about interactive timing
   behaviors. Modular composability is still possible, but within rigid constraints (chaining via
   :SUBFLOKKR) to prevent hidden scheduling issues.
   
## (4) Develop in an hour. Deploy anywhere.

Full-featured, mouse-driven terminal UI applications should work remotely via SSH, or 
browser-based via TTYD.

In the future, we will:
- Provide documentation on easy one-click multi-region deployment via [fly.io](http://fly.io)
- Add enhanced support for mobile deployment (via TTYD)

## Recommended conventions

We have found the following prefix naming conventions to be useful when structuring our own TUIs:

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
- FLOKKR & MEADHORN require SBCL. BIFROST/SKALD are portable.

## Status

v0.0 - Core API subject to change

## Alternatives

[cl-tuition](https://github.com/atgreen/cl-tuition)

## License

MIT
