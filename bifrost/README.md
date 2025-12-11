
# Bifrost 🌈

In Norse mythology, Bifrost is the rainbow bridge connecting Midgard (realm of mortals) to Asgard (realm of gods). Similarly, Bifrost connects your SBCL program to Unix-like terminal emulators like xterm, gnome-terminal, iTerm2, Mac OSX Terminal, TTYD, etc.

Bifrost is a Common Lisp library for reading from & controlling the terminal. Part of the OLD-NORSE terminal toolkit. It is the low-level infrastructure powering Skald and Flokkr.

Key features:
 - Two-way mapping between s-expressions & raw ASCII escape sequences
 - Low-level logic for XTERM mouse event tracking
 - Low-level logic for defining clickable/hoverable regions of the screen (cboxes)
 - Raw IO handling for faster communication with the terminal
 - Debugging modes to troubleshoot terminal UI (TUI) applications within SLIME/EMACS REPL

Requirements
- Unix-like terminal emulator that implements standard TTY interface (xterm, gnome-terminal, iTerm2, Mac OS X Terminal, TTYD, etc).
  - The terminal must support SGR mode (required for larger grid size).
  - To use mouse tracking features, the terminal must support XTERM mouse tracking protocol. (This isn't part of the official ANSI standard but is widely adopted as defacto standard & supported by most modern terminal emulators.)
- Bifrost is implementation-dependent on SBCL.


# Quick start playbook

Normally you would use BIFROST with FLOKKR & SKALD. The examples below are just to illustrate how BIFROST works under the hood.

**Run these examples in the terminal, not SLIME/EMACS**

Print keystrokes & mouse clicks
```lisp 
(bifrost:with-bifrost
  (bifrost:with-mouse-tracking (1003)
    (bifrost:rune-write :clear)
    (bifrost:rune-write :move-cursor) ; move the cursor to upper left hand corner
    (format sb-sys:*tty* "~% type keys, move mouse, &/or click on the screen!")
    (format sb-sys:*tty* "~% q to quit")
    (force-output sb-sys:*tty*)
    (loop
      (bifrost:rune-read-no-hang)
      (case bifrost:*rune*
        ((nil) (sleep 0.1))
        ((#\q #\Q) (return :done))
        (otherwise
         (format sb-sys:*tty* 
                 "~%~s" 
                 (if bifrost:*rune-container* 
                     bifrost:*rune-container*
                     bifrost:*rune*))
         (finish-output sb-sys:*tty*))))))
```

A button that can be clicked on

```lisp 
(bifrost:with-bifrost
  (bifrost:with-mouse-tracking (1003)
    (bifrost:with-cbox-layer :new
      (bifrost:rune-write :clear)
      (bifrost:rune-write :move-cursor)
      (format sb-sys:*tty* "~% Click the button")
      (format sb-sys:*tty* "~% q to quit")
      (flet ((place-button (text row col)
               (bifrost:rune-write `(:move-cursor ,row ,col))
               (write-string text sb-sys:*tty*)
	             (bifrost:register-cbox! text row col (+ row 1) (+ col (length text)))
               (bifrost:rune-write `(:move-cursor ,(+ row 3) 1))))
        (place-button "BUTTON A" 5 10)
        (place-button "BUTTON B" 7 10)
        (force-output sb-sys:*tty*))
      (loop
        (bifrost:rune-read-no-hang)
	      (case bifrost:*rune*
          ((nil) (sleep 0.1))
          ((#\q #\Q) (return :done))
          (otherwise
           (when (or bifrost:*pressed-cbox* bifrost:*hover-cbox*)
             (format sb-sys:*tty*
                     "~%~S ~S"
                     (or bifrost:*pressed-cbox* bifrost:*hover-cbox*)
                     bifrost:*rune-container*)
             (force-output sb-sys:*tty*))))))))
```


Quering the terminal size
```lisp
(bifrost:with-bifrost 
  (bifrost:rune-write :query-terminal-size))
```

---------------

# Key concepts

## Important setup form (WITH-BIFROST)

Wrap your enture TUI application in WITH-BIFROST

## Escape sequences

Terminal emulators use ESCAPE SEQUENCES, which are special multi-character sequences, to represent events that can't be represented with a single ASCII character. 
- INPUT TO THE TERMINAL: You can use escape sequences to trigger low-level commands such as changing the background color or clearing the screen.
- OUTPUT FROM THE: The terminal sends some events as escape sequenecs, such as pressing an arrow key on the keyboard or moving the mouse. 

RUNE-READ/RUNE-WRITE map between escape sequences & simple s-expressions in order to make it easier to interact with the terminal emulator from lisp.

## Runes

RUNE-READ/RUNE-WRITE are like READ-CHAR/WRITE-CHAR except that they read/write "runes", which can be either of the following:
 - "Simple runes" which are characters like `#\a` or `#\Newline`
 - "Complex runes", which are list of the format  `` `(,RUNE ,@PAYLOAD) `` that represent an escape sequence. Example: `(:MOVE-CURSOR row column)` or `(:UP-ARROW)`

RUNE-READ sets `*RUNE*, *RUNE-PAYLOAD*, *RUNE-CONTAINER*` with each call.

RUNE-READ-NO-HANG is like RUNE-READ except that it returns immediatly. If nothing was read, it sets `*RUNE*, *RUNE-PAYLOAD*, *RUNE-CONTAINER*` all to NIL.

   
## Cboxes & cbox layers

If you define a click region with `REGISTER-CBOX!`, then raw mouse events such as `(:MOUSE-CLICK-LEFT row column)` are transformed into CBOX events such as `(:CBOX-CLICK-LEFT row column)` 

The CBOX related runes are:
- `:CBOX-CLICK-LEFT, :CBOX-CLICK-MIDDLE, :CBOX-CLICK-RIGHT` - A button is left clicked, but not yet released.
- `:CBOX-RELEASE` - comes after left/middle/right click
- `:CBOX-UNCLICK-LEFT` - When the user clicks, then moves off of the button region before releasing in order to abort the click
- `:CBOX-HOVER` - like `:MOUSE-HOVER`, but over a CBOX

When CBOXES are interacted with, RUNE-READ sets the following: 
- `*HOVER-CBOX*, *HOVER-CBOX-CONTAINER*` - a CBOX currently being hovered over
- `*PRESSED-CBOX*, *PRESSED-CBOX-container*` - a CBOX currently being held down by a left click


Use WITH-CBOX-LAYER to accumulate & discard cbox registrations.


## Mouse events

BIFROST has been tested with the following XTERM mouse tracking modes:
- 1000 - basic click/release actions
- 1003 - hover-over events

The terminal needs to support SGR mode. This is needed for mouse tracking works with large screens

BIFROST has not yet been tested with:
 - XTERM 1001 mode for selecting blocks of text to implement features like cut/paste
 - XTERM 1002 mode, for click-drag events
     

## Debugging modes

When running outside of a Unix-like terminal emulator (eg: loading in SLIME/EMACS), WITH-BIFROST automatically puts the app into a special "read-debug" mode:
  1. you must send a #\newline (hit ENTER) to send a burst of characters to BIFROST 
    (this is to bypass any read buffers getting in the way)
  2. you can use the #\~ character as a special prefix allowing you to enter rune literals
     (note: this only works as the first thing you send after the last #\newline)
       ~:up-arrow
       ~(:move-cursor 2 2)
       ~#\a
       ~#\~

You can also put the app into "write-debug" mode by setting `BIFROST:*BIFROST-DEBUG-MODE*` to one of the following values:
- :HUMAN-READABLE - suppress all escape sequence characters
- :MACHINE-READABLE - print escape character readably, so that escape sequences can be inspected.
                    use this mode for unit testing TUI apps


---------------



# API

## Setup

Wrap your entire TUI application within WITH-BIFROST:

`WITH-BIFROST (&body body)`
  - when called at the top-level:
    - enters raw IO mode to bypass line buffering by the terminal.
    - initializes `*BIFROST-IO*, *BIFROST-TTY-P*`
    - IO buffer cleanup before/after
    - clears `*PRESSED-CBOX*, *HOVER-CBOX*` after
  - If `BIFROST-TTY-P*` is null, executes BODY within a special "read-debug" mode that uses polling & requires newlines to force terminal input past the read buffer
  - it's safe to call WITH-BIFROST recursively.
    - FLOKKR calls WITH-BIFROST under the hood, so you are able to run FLOKKR outside of WITH-BIFROST. However, it's recommended good convention to wrap your entire program within WITH-BIFROST, including FLOKKR.
   
WITH-BIFROST sets these variables:
   
`*BIFROST-TTY-P*`
 - Truthy if inside a Unix-like terminal emulator like xterm, gnome-terminal, iTerm2, Mac OSX Terminal, TTYD, etc.
  
`*BIFROST-IO*`
 - set by `WITH-BIFROST` as a way to write to/from the terminal
 - Normally, you would use SKALD instead of interacting with this directly. If you do interact with this directly, remember to call FORCE-OUTPUT/FINISH-OUTPUT.


## Sending runes to the terminal

`RUNE-WRITE (rune-or-char)`
 - send `RUNE-OR-CHAR` to `*BIFROST-IO*`
 - runes with no payload can be provided as a keyword or a list, so `:HIDE-CURSOR` & `(:HIDE-CURSOR)` are treated as the same 
 - see below for full dictionary of known tokens

## Reading runes from the terminal

`RUNE-READ ()`
  - like `READ-CHAR`, except that:
    1. it reads from `*BIFROST-IO*`
    2. Multi-character escape sequences are converted to s-expressions we call the return value of `RUNE-READ` a "rune". A rune is either:
       - a "simple rune", which is a character, as would be returned by `READ-CHAR` (eg: `#\a` or `#\Newline`)
       - a "complex rune", which is list of the format `(NAME . PAYLOAD)` representing an escape sequence (eg: `(:MOVE-CURSOR ROW COLUMN)` or `(:UP-ARROW)`)
    3. always sets `*RUNE*,*RUNE-PAYLOAD*, *RUNE-CONTAINER*`
    4. based on CBOX interactions, may also set: `*pressed-cbox*,*pressed-cbox-container*,*hover-cbox*,*hover-cbox-container*`. 

`RUNE-READ-NO-HANG ()`
  - like `RUNE-READ` excect that if if there's nothing to read, then it returns `NIL` instead of hanging. This is the `READ-CHAR-NO-HANG` version of `RUNE-READ`
  - NOTE: `RUNE-READ-NO-HANG` actually sometimes does do a very small amount of hanging: when processing escape sequences (see `*RUNE-READ-ESCAPE-SEQUENCE-MAX-HANG*` for more info)

`*RUNE-READ-ESCAPE-SEQUENCE-MAX-HANG*`
  - the only way to tell the difference between an escape sequence & the user hitting ESC is to both (1) see if the characters that come next match a known escape sequence & (2) track the delay between characters (escape sequences should send all the characters at once). This parameter controls how many seconds to wait between characters before deciding that a sequence of valid escape sequence characters was sent too slowly to be an escape sequence
  - it is used by both `RUNE-READ` & `RUNE-READ-NO-HANG` to process escape sequences
  - if you set `*RUNE-READ-ESCAPE-SEQUENCE-MAX-HANG*` to NIL, then you can enter escape sequences character-by-character by hand for testing/debugging purposes
  - it defaults to 0.01
    - if you are using local connection you could turn this down (eg: 0.05)
    - if you are on a very high latency remote connection (eg SSH or TTYD) you might want to turn this up (eg: 0.15-0.2)


Tracking mouse events

`WITH-MOUSE-TRACKING ((&optional (mode 1000)) &body body)`
  - instruct the terminal to capture & send mouse tracking events, via XTERM mouse tracking standard, then turn it off when done executing `BODY`
  - can be set to:
    - 1000 - basic click/release actions
    - 1001 - can selecting blocks of text to implement features like cut/paste (untested)
    - 1002 - click-drag events (untested)
    - 1003 - all mouse events, including hover-over events

`*BIFROST-MOUSE-TRACKING-MODE*`
  - if within `WITH-BIFROST-MODE-MOUSE-TRACKING-MODE` this will be the mode, otherwise it will be `NIL`.


Defining & managing CBOX click regions

`WITH-CBOX-LAYER (scope &body body)`
  - creates a scoping layer for collecting & discarding CBOXES registered by `REGISTER-CBOX!`
  - if SCOPE is:
    - :INHERIT any current CBOX layers defined by the outer scope are reused/preserve.
    - :NEW then the CBOX stack is reset
  - once `WITH-BIFROST-CBOX` returns, new CBOXES registed by `REGISTER-CBOX!` within `BODY` will be forgotten

`REGISTER-CBOX! (identifier min-row min-column max-row max-column)`
  - defines a new CBOX, mapping to a rectangular area on the screen
    - `MIN-COLUMN`/`MIN-ROW` should define the upper left hand corner of the rectangle
    - `MAX-COLUMN`/`MAX-ROW` should define the lower right hand corner of the rectangle

Reading mouse/tap events from the terminal

 - `FIND-CBOX (row column)` - Exposed to troubleshoot CBOXES matching based on terminal row/column. 


## debugging

When run outside of a Unix-like terminal emulator (eg: when loading SLIME/EMAC), WITH-BIFROST automatically enters a special "read-debug" mode. In this mode:
  1. you must send a #\newline (hit ENTER) to send a burst of characters to BIFROST 
    (this is to bypass any read buffers getting in the way)
  2. you can use the #\~ character as a special prefix allowing you to enter rune literals
     (note: this only works as the first thing you send after the last #\newline)
       ~:up-arrow
       ~(:move-cursor 2 2)
       ~#\a
       ~#\~

You can change the special prefix character allowing you to enter rune literals:

`*RUNE-READ-DEBUG-LITERAL-CHAR*`
 - defaults to `#\~`
 - when in debug mode, this character instructs RUNE-READ to read a literal value using `COMMON-LISP:READ`. This allows you to send rune literals to `RUNE-READ` when debugging/troubleshooting in the REPL


You can also put the app into "write-debug" mode:

`*BIFROST-DEBUG-MODE*`
  - Defaults to `NIL`
  - set of to one of the following to enter "write-debug" mode:
    - `:MACHINE-READABLE` - print #\Esc as a readible ASCII. this is useful to inspect the control commands you are sending the terminal & also for unit testing
    - `:HUMAN-READABLE` - supress escape sequences. filtering them out makes it easier to debug the rest of your application


## Advanced features

`RUNE-WRITE-RAW ()` - just like `RUNE-READ` except that responses from sending queries such as `:QUERY-TERMINAL-SIZE` are not read or parsed.

`RUNE-READ-RAW (), RUNE-READ-RAW-NO-HANG ()` - these two functions are just like `RUNE-READ` / `RUNE-READ-NO-HANG` except that mouse events (like `:MOUSE-CLICK-LEFT`) are NOT converted to CBOX events (like `:CBOX-CLICK-LEFT`) when a CBOX is matched


---------------

# RUNE-WRITE: RUNE DICTIONARY

## A NOTE ABOUT SYNTAX

RUNE-WRITE treats keywords as one-element lists as equivalent. So, for example, :QUERY-DIMENSIONS and (:QUERY-DIMENSIONS) are treated the same.


## COLORS

    ESCAPE SEQ           RUNE-TOKEN
    --------------------------------------
    ESC [ 3 color m      (:FORGROUND color)
    ESC [ 4 color m      (:BACKGROUND color)

These are the understood colors:

    COLOR        FG      BG
    ------------------------
    Black        30      40
    Red          31      41
    Green        32      42
    Yellow       33      43
    Blue         34      44
    Magenta      35      45
    Cyan         36      46
    White        37      47
    Default      39      49
    Reset        0       0



## CURSOR MOVEMENT & VISIBILITY

    RUNE-TOKEN                    ESCAPE SEQ                NOTES
    ----------------------------------------------------------------
    :HIDE-CURSOR                  ESC [ ? 2 5 l
    :UNHIDE-CURSOR                ESC [ ? 2 5 h
    :QUERY-CURSOR-POSITION        ESC [ 6 n                 returns (:CURSOR-POSITION row column)
    :MOVE-CURSOR                  ESC [ H                   move to upper left hand corner
    (:MOVE-CURSOR row column)     ESC [ row ; column H
    (:NUDGE-CURSOR row column)    ESC [ row B
                                  ESC [ row A
                                  ESC [ column C
                                  ESC [ column D

Notes:
 - with not payload, :MOVE-CURSOR moves the cursor to the home position (upper left hand corner); with payload, it moves the cursor to an abslution position
 - :NUDGE-CURSOR moves it relative to the current position. Under the hood, it sends multiple escape sequences
 - RUNE-READ does not currently support the return sequence for :QUERY-CURSOR-POSITION



## INTERACTING WITH THE TERMINAL SCREEN

    RUNE-TOKEN           ESCAPE SEQ             NOTES
    -------------------------------------------------------------------------------
    :QUERY-SIZE          ESC [ 1 8 t            returns (:TERMINAL-SIZE row column)
    :CLEAR               ESC [ 2 J              Clear (erase) the terminal screen
    :RESET               ESC [ 0 m              Reset/initialize terminal



## MOUSE TRACKING

Turn on/off mouse tracking modes. MODE should be 1000, 1002, or 1003. Currently, only mode 1000 is fully supported by RUNE-READ

SGR mode is needed to support large screen sizes. WITH-MOUSE-TRACKING enables it by default

    RUNE-TOKEN                       ESCAPE SEQ              NOTES
    ----------------------------------------------------------------------------------------
    (:MOUSE-REPORTING mode t)        ESC [ ? mode h          Enable mouse reporting MODE
    (:MOUSE-REPORTING mode nil)      ESC [ ? mode l          Disable mouse reporting MODE
    (:SGR-MOUSE-REPORTING t)         ESC [ ? 1 0 0 6 h       Enable SGR mouse reporting
    (:SGR-MOUSE-REPORTING nil)       ESC [ ? 1 0 0 6 l       Disable SGR mouse reporting


## UNSUPPORTED (FOR REFERENCE)


    ESCAPE SEQ     NOTES
    -------------------------------
    ESC [ # A      cursor up
    ESC [ # B      cursor down
    ESC [ # C      cursor forward
    ESC [ # D      cursor backward
    ESC [s         save current cursor position
    ESC [u         restore position after Save Cursor
    ESC [7         same as ESC[s??
    ESC [8         same as ESC[u??
    ESC [ K        erase from cursor until the end of the current line
    ESC [1K        erase from cursor until the end of the current line
    ESC [2K        erase the entire current line
    ESC [J         erase current line down to the bottom of the screen
    ESC [1J        erase current line up to the top of the screen
    ESC [2J        erase the screen
    ESC c          reset terminal
    ESC [ 7 h      enable text wrap
    ESC [ 7 1      disable text wrap
    ESC (          set default font
    ESC )           set alternate font


    ESCAPE SEQ          NOTES
    ---------------------------------
    ESC [ M 6 4 ^ @      scroll up
    ESC [ M 6 5 ^ @      scroll down
    ESC[1;34;{...}m      set graphics mode for cell, seperated by ";"
    ESC[0m               reset all styles/colors
    ESC[1m	ESC[22m	     set/unset bold mode.
    ESC[2m	ESC[22m	     set/unset dim/faint mode.
    ESC[3m	ESC[23m	     set/unset italic mode.
    ESC[4m	ESC[24m	     set/unset underline mode.
    ESC[5m	ESC[25m	     set/unset blinking mode
    ESC[7m	ESC[27m	     set/unset inverse/reverse mode
    ESC[8m	ESC[28m	     set/unset hidden/invisible mode
    ESC[9m	ESC[29m	     set/unset strikethrough mode.



---------------

# RUNE-READ: RUNE DICTIONARY

## ARROW KEYS

    ESCAPE SEQ     RUNE
    -------------------------
    ESC [ A        (:UP-ARROW)
    ESC [ B        (:DOWN-ARROW)
    ESC [ C        (:RIGHT-ARROW)
    ESC [ D        (:LEFT-ARROW)


## MOUSE EVENTS

by default, WITH-MOUSE-TRACKING enables SGR mode. In SGR mode, integers are encoded in multi-character sequences (like the kind you would pass to PARSE-INTEGER):

    ESCAPE SEQ                     RUNE
    ---------------------------------------------
    ESC [ < 0  ; column ; row M    (:MOUSE-CLICK-LEFT   row column)
    ESC [ < 1  ; column ; row M    (:MOUSE-CLICK-MIDDLE row column)
    ESC [ < 2  ; column ; row M    (:MOUSE-CLICK-RIGHT  row column)
    ESC [ < 3  ; column ; row M    (:MOUSE-RELEASE      row column)
    ESC [ < 32 ; column ; row M    (:MOUSE-MOVE         row column)  ;; MOUSE-DRAG-LEFT
    ESC [ < 33 ; column ; row M    (:MOUSE-MOVE         row column)  ;; MOUSE-DRAG-MIDDLE
    ESC [ < 34 ; column ; row M    (:MOUSE-MOVE         row column)  ;; MOUSE-DRAG-RIGHT

    ESC [ < 0  ; column ; row m    (:MOUSE-RELEASE      row column)
    ESC [ < 1  ; column ; row m    (:MOUSE-RELEASE      row column)
    ESC [ < 2  ; column ; row m    (:MOUSE-RELEASE      row column)
    ESC [ < 3  ; column ; row m    (:MOUSE-RELEASE      row column)
    ESC [ < 32 ; column ; row m    (:MOUSE-RELEASE      row column)
    ESC [ < 33 ; column ; row m    (:MOUSE-RELEASE      row column)
    ESC [ < 34 ; column ; row m    (:MOUSE-RELEASE      row column)
    ESC [ < 35 ; column ; row m    (:MOUSE-MOVE         row column)

      
NOTE: BIFROST coerces some events for portability, to abstract away inconsistencies between different terminals.


# LEGACY MOUSE EVENTS MODE (FOR REFERENCE ONLY)

If SGR mode was disabled, then button/row/column values would be encoded in a single ASCII char, creating the limitation of only being able to go up to a certain row/column value. Support for this mode has been turned OFF, but FWIW here is how the mapping would work for reference:

    ESCAPE SEQ                  RUNE
    --------------------------------------
    ESC [ M 32 column row       (:MOUSE-CLICK-LEFT   row column)
    ESC [ M 33 column row       (:MOUSE-CLICK-MIDDLE row column)
    ESC [ M 34 column row       (:MOUSE-CLICK-RIGHT  row column)
    ESC [ M 35 column row       (:MOUSE-MOVE row column)  ;; MOUSE-DRAG-LEFT
    ESC [ M 64 column row       (:MOUSE-MODE column)  ;; MOUSE-DRAG-MIDDLE
    ESC [ M 65 column row       (:MOUSE-MOVE row column)  ;; MOUSE-DRAG-RIGHT
    ESC [ M 66 column row       (:MOUSE-MOVE         row column)
    ESC [ M 67 column row       (:MOUSE-RELEASE      row column)

## CBOX EVENTS

If a CBOX is matched then a CBOX event will be returned instead:

    (:CBOX-CLICK-LEFT   row column)
    (:CBOX-CLICK-MIDDLE row column)
    (:CBOX-CLICK-RIGHT  row column)
    (:CBOX-RELEASE      row column)
    (:CBOX-UNCLICK-LEFT row column)
    (:CBOX-HOVER        row column)
  
These are something made by BIFROST. They aren't part of the ANSI standard.


## MISC EVENTS

These are the responses to querying terminal dimensions ("ESC[18t") & querying cursor position ("ESC(6n"):

    ESCAPE SEQ                         RUNE
    ------------------------------------------------------------------------------
    ESC [ 8 ; rows ; columns t         (:TERMINAL-SIZE row column)
    ESC [ row ; column R               (:CURSOR-POSITION row column)


---------------

# MORE ABOUT XTERM MOUSE EVENT TRACKING

mouse event tracking is defined as part of the xterm control sequences, which are widely adopted as a defacto standard by modern terminal emulators, but not part of the official ANSI standard

here is some documentation, mostly taken or paraphrased from:

https://www.xfree86.org/current/ctlseqs.html#Mouse%20Tracking

mouse tracking can be turned on/off with the following:

    [ ? mode h       enable on MODE
    [ ? mode l       disable MODE

modes options:

    1000     Normal tracking mode sends an escape sequence on both button press and release.
    1001     Mouse highlight tracking notifies a program of a button press, receives a range of
             lines from the program, highlights the region covered by the mouse within that
             range until button release, and then sends the program the release coordinates. 
    1002     Button-event tracking is essentially the same as normal tracking, but xterm also
             reports button-motion events. Motion events are reported only if the mouse pointer
             has moved to a different character cell
    1003     Any-event mode is the same as button-event mode, except that all motion events
             are reported, even if no mouse button is down

when not in SGR mode, mouse click events look somelike like this:

    ESC M button row column

BUTTON/COLUMN/ROW are encoded as a single ASCII character
  - subtract 32 from the CHAR-CODE to get the value
  - if you are using UTF-8, this causes problems of values over a certain size

here is how to parse the button state:

     Bits 0-1: low two bits encode button info
        0=left button
        1=middle button
        2=right button
        3=release (no button pressed)
     Bits 2: modifier keys (shift, ctrl, meta)
        4=Shift
        8=Meta
        16=Control
      - Note however that the shift and control bits are normally unavailable because xterm uses the control modifier with mouse for popup menus, and the shift modifier is used in the default translations for button events.
      - The Meta modifier recognized by xterm is the mod1 mask, and is not necessarily the "Meta" key (see xmodmap).
        Bits
      Bits 6-7: drag state

Note: Wheel mice may return buttons 4 and 5. Those buttons are represented by the same event codes as buttons 1 and 2 respectively, except that 64 is added to the event code. Release events for the wheel buttons are not reported.

Motion events are reported only if the mouse pointer has moved to a different character cell.
  * On button press or release, xterm sends the same codes used by normal tracking mode.
  * On button-motion events, xterm adds 32 to the event code (the third character, C b ). The other bits of the event code specify button and modifier keys as in normal mode. For example, motion into cell x,y with button 1 down is reported as ESC M @ {x} {y} where @ = 32 + 0 (button 1) + 32 (motion indicator) Similarly, motion with button 3 down is reported as ESC M {b} {x} {y} where B = 32 + 2 (button 3) + 32 (motion indicator)

Example Click Events:

1. Left Click (at X=10, Y=5):
   ESC [ M 32 42 37
     - <button> = 32 (0 + 32 for left button).
     - X = 42 - 32 = 10
     - Y = 37 - 32 = 5

2. **Button Release** (at X=10, Y=5):
   ESC [ M 35 42 37
     - <button> = 35 (3 + 32 for button release)

To differentiate a click from a drag, you can track the sequence of events:
  1. a click consists of a button press (<button> = 32/33/34) followed immediately by a button release (<button> = 35/36/37) without any intervening drag events.
  2. A drag involves button press followed by one or more drag events (<button> values including the drag bit) before the release


UPDATE: I'm also seeing terminals return sequences ending in "m" to indicate mouse button instead of using button event 3. Eg:

    ESC [ < 0  ; column ; row M    (:MOUSE-CLICK-LEFT   row column)
    ESC [ < 0  ; column ; row m    (:MOUSE-RELEASE      row column)


-----------

Bifrost is a rainbow bridge that connects the realm of the gods, Asgard, to Midgard, the realm of mortals
 - It is made of fire & is said to be the strongest bridge ever built
 - The thunder god Thor was not allowed to use the bridge because he was so strong that he could break it
 - The gods crossed it daily to meet and make decisions at the Well of Urd
 - Prophecy is that the bridge will be destroyed at the end of the world, Ragnarok, when the giants & the  dead attack Asgard. So plan accordingly!!
