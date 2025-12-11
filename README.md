



#  The Old Norse terminal toolkit

Old Norse is collection of Common Lisp libraries for building fast, mouse-driven Terminal UI (TUI) applications that work remotely via SSH (or browser-based via [TTYD](https://tsl0922.github.io/ttyd/)).

Old Norse is primarily used for prototyping games. But it's also useful for building internal tools (eg: system monitoring, log viewers, build status, etc) or interactive data visualizations (charts, tables, real-time data feeds, etc). 

## Requirements
- Unix-like terminal emulator that implements standard TTY interface (xterm, gnome-terminal, iTerm2, Mac OS X Terminal, TTYD, etc).
  - The terminal must support SGR mode (required for larger grid size).
  - To use mouse tracking features, the terminal must support XTERM mouse tracking protocol. (This isn't part of the official ANSI standard but is widely adopted as defacto standard & supported by most modern terminal emulators.)
- Monospaced font
- Old Norse is implementation-dependent on SBCL

## Libraries 

### Skald
[Skald](skald/) is a high-level terminal UI and animation framework
- Treat blocks of ASCII/unicode text as sprites (transparant char enables composite layering)
- Terminal grid based positioning/layout/alignment, foreground/background colors, cropping/fill, emojis, etc
- Optimized for fast screen redrawing with minimal flicker

### Flokkr
[Flokkr](flokkr/) is a concurrency library purpose-built for building interactive TUI applications with skald/bifrost.
- Manage complex timing & behaviors loops via mini-DSL (inspired by the LOOP macro)
- Respond instantly to terminal input from user (without relying on polling)
- Define widget/object timing behaviors seperately, then compose via :SUBFLOCKKR

### Bifrost 🌈
[Bifrost](bifrost/) is a low-level utility for reading from & controlling the terminal. Used by skald & flokkr
- Two-way mapping between ASCII escape sequences & s-expressions
- Mouse click/hover event tracking logic
- Raw I/O to bypass terminal read buffer (but also debugging modes to troubleshoot TUI applications within SLIME/EMACS)

### Meadhorn
[Meadhorn](meadhorn/) is a simple debugging utility. 
- Print statements are a simple, powerful debugging tool. But when developing terminal applications, they mess up the display. MEADHORN:MH is just like FORMAT except that it broadcasts output to a Unix socket. Read it with [netcat](https://en.wikipedia.org/wiki/Netcat) for simple print-statement based debuging without disrupting the terminal UI.

### Old Norse
You can load all of these libraries via the umbrella package `(require :old-norse)`


## Quick Start

**Run these examples in the terminal, not SLIME/EMACS**

Clear the screen & render a simple sprite

```lisp
(bifrost:with-bifrost             ; low-level setup
  (skald:skald-init)              ; clear the screen
  (skald:skald ()                 ; bundle set of updates the screen
    (skald:sprite (3 3 :fg :cyan) ; draw an ASCII sprite
      "╔═══════════════╗"
      "║ Hello, world! ║"
      "╚═══════════════╝")))
```


Fast animation that follows mouse movement
```lisp
(bifrost:with-bifrost                 ; low-level setup
  (skald:skald-init)                  ; clear the screen
  (bifrost:with-mouse-tracking (1003) ; track mouse movement
    (flokkr:flokkr
      (:input
        (:mouse-click-left (return-from flokkr:flokkr)) ; on left click, exit
        (:mouse-move                                    ; on mouse move, reposition
         (skald:skald ()
           (skald:sprite ((first bifrost:*rune-payload*)  ; row
                          (second bifrost:*rune-payload*) ; col
                          :fg :cyan                       ; forgeround color
                          :align :center)                 ; sprite alignment
                "╔═══════════════╗"
                "║ Hello, world! ║"
                "╚═══════════════╝"))))))))
```


Mouse movement tracking + seperate simultaneous animation timing loop (stopwatch)

```lisp
(bifrost:with-bifrost                          ; low-level setup
  (skald:skald-init)                           ; clear the screen
  (bifrost:with-mouse-tracking (1003)          ; track mouse hover events
    (bifrost:with-cbox-layer :new
      (let ((seconds 0)
            (row 1)
            (col 1))
        (flokkr:flokkr
          (:after 1 :do (incf counter) :repeat) ; every second, advance the timer
          (:input
            (:mouse-click-left (return-from flokkr:flokkr)) ; on left click, exit
            (:mouse-move                                    ; on mouse move, reposition
             (setf row (first *rune-payload*)
                   col (second *rune-payload*))))
          (:also (skald:skald-draw ()          ; if either of the above happened, re-render
                   (skald:span (row col :foreground cyan)
                     (format nil "~a seconds" seconds))))))))]
```

# ## Design pillars

Together, the Old Norse libraries form a grid-based terminal graphics engine, that runs on Unix-like terminal emulators, with focus on UI speed/responsiveness & rapid development.

## (1) Low-level grid-based terminal graphics engine

Old Norse doesn't provide you with a widget for making a status bar. It provides you with tools to draw spans/sprites to the screen & animate them as you like, so that you can make your own customized status bar. The goal of the library is to make it easy to prototype a wide array of experimental game mechanics and interfaces, so long as they can be represented on a chunky terminal grid, within the constraints of a Unix-like terminal emulator.
 
In the future, we will add support for [sixel](https://en.wikipedia.org/wiki/Sixel) graphics. This will allow us to display and (conservatively) animate graphic images, including images of text in various sizes, layouts, and fonts. However, the terminal grid will still remain the only coordinate system. Sixel sprites will snap to the same grid.

## (2) UX speed & precision timing

Timing is critical to games. Speed & responsiveness are important to any kind of user application. Design goals:
 1. Update screen within 16ms of user input (if run over remote connection, assumes within same geographic region)
 2. 60fps animation (assumes normal screen size)
 3. High-precision control of timings & interactive behavior

Based on our observation, TUI applications can achieve this by managing the following bottlenecks:
1. Efficient diff-based screen updates - provided by SKALD
2. Immediate response to user input - provided by FLOKKR
3. Get slow DB queries & cloud API calls out of main loop - There is a roadmap plan to add a new flokkr form for async io. Until then, this must be managed by the user.
4. Strategic scheduling of GC pauses -  Must be managed by the user. (Note: bifrost/skald do produce GC pressure. There is a roadmap plan to reduce it over time.)
5. When deploying remotely, keep in-region - must be managed by the user.
  
## (3) Develop in an hour. Deploy anywhere.

Focus on rapid development
- 1:1 mapping between back-end SBCL program & client session
- DSL-based approach

Easy remote deployment
- SSH
- Browser-based via TTYD.

In the future, we plan to also:
- Document instructions for easy, one-click multi-region deployment via [fly.io](http://fly.io)
- Document Practical tips for minimizing cost of scaled Old Norse deployments
- Add enhanced support for mobile

## (4) Old Norse "high locality" coding style

If not structured correctly, even the simplest Terminal UI application can grow into a complicated mess of spaghetti code. The Old Norse way to deal with this is by prioritizing locality. In other words, the TUI application code structure should put related logic close together.

1. JUST ONE FUNCTION TO RENDER THE ENTIRE SCREEN - SKALD-DRAW makes efficient diff-based screen updates, only updating sections of the that have recently changed. This allows you to define a single function to draw the entire screen, and then call it however frequently you want, relying on SKALD's low-level optimization to eliminate unecessay redrawing.

2. JUST ONE CONTROL STRUCTURE - FLOKKR makes it possible to put all timing logic & input reaction logic in one place, making it easier to reason about timing & interactive behaviors. Modular composability is still possible, but within rigid constraints (chaining via :SUBFLOKKR) to help prevent hidden scheduling issues.

In practice, we have found this design pattern to *DRASTICALLY* simplify & shorten TUI application codebases.


## Recommended conventions

We have found the following prefix naming conventions to be useful when structuring our own TUIs:

```lisp 
;;   <r>-row        row coordinate on the terminal grid (sometimes called Y)
;;   <c>-column     column coordinate on the terminal grid (sometimes called X)
;;   <rc>-point     a cons of (ROW . COLUMN). Sometimes called a "point"
;;   [d]-duration   duration of seconds elapsed or for a timer to wait
;;   [%]-progress   for tracking transition from 0.0 to 1.0 (state machine or animation)
;;   [n]-ticks      number of ticks/frames for something to run (eg for an animation)
```

## Status

v0.0 - Core API subject to change

## Lispy alternatives

- [cl-tuition](https://github.com/atgreen/cl-tuition) - Common Lisp library for building rich, responsive terminal user interfaces (TUIs). It blends the simplicity of TEA with the power of CLOS so you can model state clearly, react to events via generic methods, and render your UI as pure strings.
- [text-draw](https://shinmera.github.io/text-draw/) - Common Lisp functions to draw graphics using pure Unicode text.

## License

MIT
