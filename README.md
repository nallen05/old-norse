



# OLD-NORSE Terminal Toolkit

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

### [Bifrost](bifrost/README.md) 🌈
Low-level terminal I/O and escape sequence handling
- Lisp API for reading from & controlling the terminal
- Low-level support for mouse event tracking
- Uses raw I/O for faster performance (includes debugging mode to troubleshoot terminal apps
  within SLIME/EMACS or other REPL)


### [Skald](skald/README.md)
High-level terminal UI and animation framework
- Treat blocks of ASCII and unicode text as sprites
- Supports features like grid-based positioning/layout, colors, transparancy, emojis, etc
- Optimizes screen updates to minimizes flicker when redrawing


### [Flokkr](flokkr/README.md)
Cooperative multitasking library, purpose built for BIFROST applications
- Manage complex timing loops
- Respond instantlt to user input
- Define widget & state-machine behaviors seperately then compose via subflockkrs


### [Meadhorn](meadhorn/)
Very simple debugging utility. 
- The simplest debugging tool is a print statement. MD is like FORMAT except that it broadcasts
  the print statement output to a Unix socket.
- Read the output with [netcat](https://en.wikipedia.org/wiki/Netcat) to debug without disrupting the terminal UI


### OLD-NORSE
You can load all of the OLD-NORSE libraries via `(require :old-norse)

## Quick Start

**Run these in the terminal, not SLIME/EMACS**

Write to the screen

```lisp
(bifrost:with-rune-raw-io  ; low-level setup
  (skald:skald-init)       ; clear the screen
  (skald:skald-draw ()     ; bundle as set of updates the screen
    (skald:sprite (3 3     ; draw an ASCII sprite
                   :foreground :cyan)
      "╔═══════════════╗"
      "║ Hello, world! ║"
      "╚═══════════════╝")))
```


Fast animation that follows mouse movement
```
(bifrost:with-rune-raw-io                  ; low-level setup
  (skald:skald-init)                       ; clear the screen
  (bifrost:with-mouse-tracking (1003)      ; track mouse hover events
    (bifrost:with-cbox t
      (flokkr:flokkr-main
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

```
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

See [examples/](examples/) for more.

## Requirements
- Terminal with XTERM mouse tracking (iTerm, Xterm, etc.)
- Monospaced font
- BIFROST/SKALD are portable. Currently, FLOKKR & MEADHORN require SBCL.

## Status

v0.0 - Core API subject to change

## License

MIT
