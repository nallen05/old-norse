
# BIFROST 🌈

BIFROST is a Common Lisp library for reading from & controlling the terminal. It is part of the OLD-NORSE terminal toolkit.

Key features:
 - Two-way mapping between s-expressions & raw ASCII escape sequences
 - Low-level logic for XTERM mouse event tracking (this isn't officially part of the official ANSI standard but is widely adopted as defacto standard supported by most modern terminal emulators)
 - Low-level logic for defining clickable regions of the screen (CBOXES)
 - Raw IO handling for faster communication with the terminal
 - Debugging features to troubleshoot terminal UI applications within SLIME/EMACS REPL

In Norse mythology, Bifrost 🌈 is the rainbow bridge connecting Midgard (realm of mortals) to Asgard (realm of gods). Similarly, Bifrost connects your Lisp program to Unix-like terminal emulators like xterm, gnome-terminal, iTerm2, Mac OSX Terminal, TTYD, etc.

# Quick start playbook

Normally you would use BIFROST with FLOKKR & SKALD. But the examples below illustrate how BIFROST works under the hood.

**Run these examples in the terminal, not SLIME/EMACS**

```
;; query terminal size
(bifrost:with-rune-raw-io
  (bifrost:rune-write :query-terminal-size))

;; draw 01234 on the screen at the row/column position 5/10
(bifrost:with-bifrost
  (bifrost:rune-write :clear)
  (dotimes (i 6)
    (bifrost:rune-write `(:move-cursor 5 ,(+ i 10)))
    (bifrost:rune-write (code-char (+ 48 i))))
  (bifrost:rune-write :move-cursor) ; move the cursor to upper left hand corner
  (values))

;; print keystrokes & mouse clicks
(bifrost:with-bifrost
  (bifrost:with-mouse-tracking ()
    (bifrost:rune-write :clear)
    (bifrost:rune-write :move-cursor) ; move the cursor to upper left hand corner
    (format sb-sys:*tty* "~% type some keys &/or click on the screen!")
    (format sb-sys:*tty* "~% q to quit")
    (force-output sb-sys:*tty*)
    (loop
      (bifrost:rune-case (bifrost:rune-read-raw-no-hang)
        (nil (sleep 0.1))
        ((#\q #\Q) (return :done))
        (otherwise
         (format sb-sys:*tty* "~%~S" bifrost:*rune*)
         (finish-output sb-sys:*tty*))))))

;; button that can be clicked on
(bifrost:with-bifrost
  (bifrost:with-mouse-tracking ()
    (bifrost:with-cbox t
      (bifrost:rune-write :clear)
      (bifrost:rune-write :move-cursor)
      (format sb-sys:*tty* "~% Click the button")
      (format sb-sys:*tty* "~% q to quit")
      (let ((row 5)
            (col 10)
            (text "THE BUTTON"))
        (bifrost:rune-write `(:move-cursor ,row ,col))
        (write-string text sb-sys:*tty*)
	      (bifrost:register-cbox! text
			                          :min-row row
                                :min-column col
                                :max-row (+ row 1)
                                :max-column (+ col (length text)))
        (bifrost:rune-write `(:move-cursor ,(+ row 3) 1))
        (force-output sb-sys:*tty*)
	      (loop
	        (bifrost:rune-case (bifrost:rune-read-no-hang)
            (nil (sleep 0.1))
            ((#\q #\Q) (return :done))
            (:cbox-release-left
             (format sb-sys:*tty*
                     "~%RUNE: ~S~%CBOX: ~S"
                     bifrost:*rune*
                     bifrost:*cbox*)
             (force-output sb-sys:*tty*))
            (otherwise nil)))))))
```

---------------

# KEY CONCEPTS

## IMPORTANT SETUP FORM: WITH-BIFROST

Wrap your enture TUI application in WITH-BIFROST

## ESCAPE SEQUENCES

Terminal emulators use ESCAPE SEQUENCES -- which are special multi-character sequences -- to represent events that can't be represented with a single ASCII character. For example, pressing an arrow key on the keyboard or moving the mouse. You can also use escape sequences to trigger low-level commands such as changing the background color or clearing the screen.

RUNE-READ/RUNE-WRITE map between escape sequences & simple s-expressions in order to make it easier to interact with the terminal emulator from lisp.

## RUNES

RUNE-READ/RUNE-WRITE are like READ-CHAR/WRITE-CHAR except that they read/write "runes", which can be either of the following:
 - "Simple runes" which are characters like `#\a` or `#\Newline`
 - "Complex runes", which are list of the format  `` `(,NAME ,@PAYLOAD) `` that represent an
    escape sequence. Example: `(:MOVE-CURSOR row column)` or `(:UP-ARROW)`

RUNE-CASE is like CASE, except that it makes it simpler to dispatch off of runes

RUNE-READ always sets `*RUNE*` to the last rune read. If it was a complex rune, then `*RUNE-NAME*` & `*RUNE-PAYLOAD*` are also set to match. Otherwise they are set to NIL.

   
## CBOXES

If you define a click region with `REGISTER-CBOX!`, then raw mouse events such as `(:MOUSE-CLICK-LEFT row column)` are transformed into CBOX events such as `(:CBOX-CLICK-LEFT row column)` & `*CBOX*` is set to the matched click region. There is also some logic added under the hood so that CBOX processing understands if a button is released or the click was aborted by moving off the button before releasing.

The CBOX related runes are:
  `(:CBOX-CLICK-LEFT row column)`
    A button is left clicked, but not yet released
  `(:CBOX-RELEASE-LEFT row column)`
    Left click & release. This is the usual thing to trigger buttonw
  `(:CBOX-UNCLICK-LEFT row column)`
    When the user clicks, then moves off of the button region before releasing in order to abort the click

## MOUSE EVENTS

BIFROST has been tested with the following XTERM mouse tracking modes:
- 1000 - basic left click/release actions
- 1003 - hover-over events

The terminal needs to support SGR mode. This is needed for mouse tracking works with large screens

BIFROST has not yet been tested with:
 - XTERM 1001 mode for selecting blocks of text to implement features like cut/paste
 - XTERM 1002 mode, for click-drag events
 - right click
     
There is currently no plan to support the following:
 - mouse wheel scrolling
 - the middle mouse button

- it initializes `*BIFROST-IO*` to send/receive info from the terminal
- it also does other important setup

## DEBUGGING MODES

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
- :NO-CONTROL - suppress all escape sequence characters
- :ESCAPE-CONTROL - print escape character readably, so that escape sequences can be inspected.
                    use this mode for unit testing TUI apps


---------------



# API

## Setup

Wrap your entire TUI application within WITH-BIFROST:

  `WITH-BIFROST (&body body)`
    - initializes `*BIFROST-IO*` & `*BIFROST-TTY-P*`
    - when `BIFROST-TTY-P*` is non-null, executes BODY within raw IO mode. This bypassess line buffering by the terminal. Otherwise, executes BODY within a special "read-debug" 
    mode
    - WITH-BIFROST can be called recursively. The top-level call flushes out the IO buffers to do cleanup in between invocations.
    - FLOKKR calls WITH-BIFROST implicitly. So you can technically run FLOKKR outside of WITH-BIFROST. But it's recommended to wrap everything within WITH-BIFROST, including FLOKKR, if you are building a TUI on top of BIFROST
    
It sets these variables:
   
  `*BIFROST-TTY-P*`
  - non-null if inside a Unix-like terminal emulator like xterm, gnome-terminal, iTerm2, Mac OSX Terminal, TTYD, etc.
  
  `*BIFROST-IO*`
   - set by `WITH-BIFROST`
   - You can write to/from to interact with terminal. If you do this, you will likely need to call FORCE-OUTPUT/FINISH-OUTPUT a lot. Recommend using SKALD instead of interacting with this directly.


## Sending runes to the terminal

  `RUNE-WRITE (rune-or-char)`
    - send `RUNE-OR-CHAR` to `*BIFROST-IO*`
    - runes with no payload can be provided as a keyword or a list, so `:HIDE-CURSOR` & `(:HIDE-CURSOR)` are treated as the same 
    - see below for full dictionary of known tokens


## Reading runes from the terminal

  `RUNE-READ ()`
    like `READ-CHAR`, except that:
      1. it reads from `*BIFROST-IO*`
      2. Multi-character escape sequences are converted to s-expressions we call the return value of `RUNE-READ` a "rune". A rune is either:
         - a "simple rune", which is a character, as would be returned by `READ-CHAR` (eg: `#\a` or `#\Newline`)
         - a "complex rune", which is list of the format `(NAME . PAYLOAD)` representing an escape sequence (eg: `(:MOVE-CURSOR ROW COLUMN)` or `(:UP-ARROW)`)
      3. `*RUNE*` is set to match the last rune read
      4. if the last rune was a complex rune, then `*RUNE-NAME*` & `*RUNE-PAYLOAD*` are set to match. if it was a simple rune they are set to NIL
     - There is another special behavior: if a mouse events like `(:MOUSE-CLICK-LEFT row column)` 
     activates a CBOX (which is a rectangular click region defined by the user), then a CBOX related event like `(:CBOX-CLICK-LEFT row column)` is sent instead
       - for more about this, see: `WITH-BIFROST-CBOX` & `REGISTER-CBOX!`
      
  `RUNE-READ-NO-HANG ()`
    - like `RUNE-READ` excect that if if there's nothing to read, then it returns `NIL` instead of hanging. This is the `READ-CHAR-NO-HANG` version of `RUNE-READ`
    - NOTE: `RUNE-READ-NO-HANG` actually does do a very small amount of hanging when processing escape sequences (see `*RUNE-READ-ESCAPE-SEQUENCE-MAX-HANG*` for more info)
      
  `*RUNE*`
  `*RUNE-NAME*`
  `*RUNE-PAYLOAD*`
    these 3 variables are set by `RUNE-READ` & `RUNE-READ-NO-HANG` to match the last rune that was read

  `*RUNE-READ-ESCAPE-SEQUENCE-MAX-HANG*`
    - the only way to tell the difference between an escape sequence & the user hitting ESC is to both (1) see if the characters that come next match a known escape sequence & (2) track the delay between characters (escape sequences should send all the characters at once). This parameter controls how many seconds to wait between characters before deciding that a sequence of valid escape sequence characters was sent too slowly to be an escape sequence
    - it is used by both `RUNE-READ` & `RUNE-READ-NO-HANG` to process escape sequences
    - if you set `*RUNE-READ-ESCAPE-SEQUENCE-MAX-HANG*` to NIL, then you can enter escape sequences character-by-character by hand for testing/debugging purposes


Tracking mouse events

  `WITH-MOUSE-TRACKING ((&optional (mode 1000) (stream *terminal-io*)) &body body)`
    - instruct the terminal to capture & send mouse tracking events, via XTERM mouse tracking standard, then turn it off when done executing `BODY`
    - currently, 1000 & 1003 have been tested

  `*BIFROST-MOUSE-TRACKING-MODE*`
    - if within `WITH-BIFROST-MODE-MOUSE-TRACKING-MODE` this will be the mode, otherwise it will be `NIL`. Currently mode 1000 is the only supported mode.


Defining & managing CBOX click regions

  `WITH-BIFROST-CBOX (reset-p &body body)`
    - setup so that `REGISTER-CBOX!`, `LOOKUP-CBOX`, `CBOX-READ` & `CBOX-READ-NO-HANG` can be called within `BODY`
    - if `RESET-P` is non-null, then a brand new context stack is created, forgetting about any CBOXES defined outside of the scope of this form. Run this when initializing a new screen or popup that takes over the entire screen
    - if `RESET-P` is null, then the current context binding is inherited & will be matched. Use this when a subscreen or popup builds upon a main screen.
    - once `WITH-BIFROST-CBOX` returns, CBOXES registed by `REGISTER-CBOX!` within `BODY` will be
      forgotten

  `REGISTER-CBOX! (identifier &key (min-row *cbox-min-row*) (min-column *cbox-min-column*) (max-row *cbox-max-row*) (max-column *cbox-max-column*))`
    - defines a new CBOX, mapping to a rectangular area on the screen
      - `MIN-COLUMN`/`MIN-ROW` should define the upper left hand corner of the rectangle
      - `MAX-COLUMN`/`MAX-ROW` should define the lower right hand corner of the rectangle

  `*CBOX-MIN-ROW*`
  `*CBOX-MIN-COLUMN*`
  `*CBOX-MAX-ROW*`
  `*CBOX-MAX-COLUMN*`
    - these are the default rectangular coordinates used by `REGISTER-CBOX!`
    - they are intended to be set by code drawing to the screen (such as `SKALD:SPRITE` before calling `REGISTER-CBOX!` to make it easier for CBOX regions to match what is drawn on the screen


Reading mouse/tap events from the terminal
 
  `LOOKUP-CBOX (row column)`
    Exposed to troubleshoot CBOXES matching based on terminal row/column.
    This is provided for debugging/troubleshooting only
     
  `CBOX-PRESSED-P (identifier &key (test #'equalp))`
   returns `T` if the CBOX with the given `IDENTIFIER` is currently pressed
   this is determined by checking `*ACTIVE-CBOX-PRESSED*`

  `*CBOX*`
     - a `CBOX` object; set by `RUNE-READ` & `RUNE-READ-NO-HANG`
     - this is the main way you know what was clicked on
     
  `*ACTIVE-CBOX-PRESSED*`
    if a CBOX is pressed, then this is set to it until it is released by reading another rune
    
  `CBOX`
  `CBOX-P`
  `CBOX-IDENTIFIER`
  `CBOX-MIN-ROW`
  `CBOX-MIN-COLUMN`
  `CBOX-MAX-ROW`
  `CBOX-MAX-COLUMN`
    for interacting with the `*CBOX*` and `*ACTIVE-CBOX-PRESSED*` objects


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
      `:ESCAPE-CONTROL`
        print #\Esc as a readible ASCII. this is useful to inspect the control commands you are sending the terminal & also for unit testing
      `:NO-CONTROL`
        supress escape sequences. filtering them out makes it easier to debug the rest of your application



## Dispatching control flow based on runes

  `RUNE-CASE (rune &body cases)`
    like CASE except more convenient to use with runes. Example:
    ```
      (rune-case (rune-read)
        (nil                  0)
        (#\a                  1)
        ((#\b #\c #\d)        2)
        (:mouse-click-left    3)
        ((:mouse-click-middle :mouse-click-right) 4)
        ((:mouse-release 1 1) 5)
        (otherwise            *rune*))
    ```



## Advanced features

  `RUNE-WRITE-RAW ()`
    just like `RUNE-READ` except that responses from sending queries such as `:QUERY-TERMINAL-SIZE` are not read or parsed.
    
  `RUNE-READ-RAW ()`
  `RUNE-READ-RAW-NO-HANG ()`
    these two functions are just like `RUNE-READ` / `RUNE-READ-NO-HANG` except that mouse events (like `:MOUSE-CLICK-LEFT`) are NOT converted to CBOX events (like `:CBOX-CLICK-LEFT`) when a CBOX is matched


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


## UNSUPPORTED


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
  ESC (      set default font
  ESC )      set alternate font

  
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
  ESC[9m	ESC[29m	     set/unset strikethrough mode.;



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
  ESC [ < 32 ; column ; row M    (:MOUSE-CLICK-LEFT   row column)
  ESC [ < 33 ; column ; row M    (:MOUSE-DRAG-MIDDLE  row column)
  ESC [ < 34 ; column ; row M    (:MOUSE-DRAG-RIGHT   row column)
  
  ESC [ < 0  ; column ; row m    (:MOUSE-RELEASE      row column)
  ESC [ < 1  ; column ; row m    (:MOUSE-RELEASE      row column)
  ESC [ < 2  ; column ; row m    (:MOUSE-RELEASE      row column)
  ESC [ < 3  ; column ; row m    (:MOUSE-RELEASE      row column)
  ESC [ < 32 ; column ; row m    (:MOUSE-RELEASE      row column)
  ESC [ < 33 ; column ; row m    (:MOUSE-RELEASE      row column)
  ESC [ < 34 ; column ; row m    (:MOUSE-RELEASE      row column)
  ESC [ < 35 ; column ; row m    (:MOUSE-MOVE         row column)

      
NOTE:there are multiple ways to trigger events that indicate that the mouse was released. BIFROST coerces them all to the same :MOUSE-RELEASE event for portability, to abstract away 
inconsistencies between different terminals.


# LEGACY MOUSE EVENTS MODE (FOR REFERENCE ONLY)

If SGR mode was disabled, then button/row/column values would be encoded in a single ASCII char, creating the limitation of only being able to go up to a certain row/column value. Support for this mode has been turned OFF, but FWIW here is how the mapping would work for reference:

  ESCAPE SEQ                  RUNE
  --------------------------------------
  ESC [ M 32 column row       (:MOUSE-CLICK-LEFT   row column)
  ESC [ M 33 column row       (:MOUSE-CLICK-MIDDLE row column)
  ESC [ M 34 column row       (:MOUSE-CLICK-RIGHT  row column)
  ESC [ M 35 column row       (:MOUSE-DRAG-LEFT    row column)
  ESC [ M 64 column row       (:MOUSE-DRAG-MIDDLE  row column)
  ESC [ M 65 column row       (:MOUSE-DRAG-RIGHT   row column)
  ESC [ M 66 column row       (:MOUSE-MOVE         row column)
  ESC [ M 67 column row       (:MOUSE-RELEASE      row column)

## CBOX EVENTS

If a CBOX is matched (see `WITH-BIFROST-CBOX` & `REGISTER-CBOX`) then a CBOX event will be returned instead:

  (:CBOX-CLICK-LEFT   row column)
  (:CBOX-RELEASE-LEFT row column)
  (:CBOX-UNCLICK-LEFT row column)
  
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
