
# Skald

Skald is a high-level terminal UI & ASCII animation framework. It is part of the Old Norse terminal toolkit.

### Features

Skald extends Bifrost to add:

- **Sprite system:** Treat blocks of ASCII text as objects. Move them, color them, & layer them. Use a transparant character to create composite layered images.
- **Efficient diff-based rendering:** Skald uses a double-buffering system. It compares the next frame to the current frame and only writes the characters that have changed. This allows fast screen updates & animation without flicker.
- **Grid layout engine:** Flexibly organize the screen into grids, columns, & windows. Bounding boxes support cropping, fill, border, & left/center/right alignment.
- **Emoji support:** Treats emojis as double-width unicode characters. Handles the logic of rendering double-width characters within monospaced grid & bounding boxes without breaking alignment or leaving artifacts.

---------

## Quick Start

**Run these examples in the terminal, not inside SLIME/EMACS.**

### 1. The Basics: Spans & Sprites

A **Span** is a single line of text. A **Sprite** is a multi-line block of text.

```lisp
(bifrost:with-bifrost   ; Enter raw terminal mode
  (skald:skald-init)    ; Initialize buffers & clear screen
  (skald:skald          ; Open a draw transaction
  
    ;; Draw a single line
    (skald:span (2 2) "Welcome to Old Norse")

    ;; Draw a multi-line sprite
    (skald:sprite (3 2)
      "  __"
      "<(o )___"
      " ( ._> /"
      "  `---'"
      "---------"
      )))
```


### 2. Styling and Alignment

Skald supports ANSI colors and text alignment (centering sprites relative to a specific point).

```lisp
(bifrost:with-bifrost
  (skald:skald-init :fg :black :bg :white) ; set new screen foreground/background color
  (skald:skald
  
    ;; draw welcoming title
    (skald:span ((- skald:*screen-center-row* 4)  ; row
                 skald:*screen-center-col*        ; column
                 :fg :magenta                     ; foreground color
                 :align :center)                  ; alignment
      "Welcome to Old Norse")

    ;; draw welcoming duck
    (skald:sprite ((- skald:*screen-center-row* 2) ; row
                   skald:*screen-center-col*       ; column
                  :align :center)                  ; alignment
      "  __"
      "<(o )___"
      " ( ._> /"
      "  `---'")
      
    ;; draw water below the duck
    (dotimes (i 10)
      (skald:span ((+ i 2 skald:*screen-center-row*) ; row
                   skald:*screen-center-col*         ; column
                   :bg :blue                         ; background color
                   :fg :white                        ; foreground color
                   :align :center)                   ; alignment
        (make-string (- 40 (* i 2)) :initial-element #\.)))))
```

### 3. Layouts: Grids, Columns, and Windows

Skald provides a grid-based layout system

  * **Grid:** The container for a layout.
  * **Column:** Stacks items vertically.
  * **Window:** A box inside a column (borders optional)

```lisp
(bifrost:with-bifrost
  (skald:skald-init)
  (skald:skald
    (skald:grid (2 2 :border t :border-fg :yellow)
      (skald:column (:width 20)
        (skald:window (:height 3)
           "Stats"
           '(:span "HP: " (:bg :red (:fg :white "11")) "/100") ; keyword mini-language
           "Mana: 50/50")
        (skald:window (:height 3 :fg :green)
           "Buffs"
           "+Str"
           "+Int"))
      (skald:column (:width 40)
        (skald:window (:height 7 :align :center)
           ""
           '(:fg :magenta "MAIN VIEW")  ; keyword mini-language
           "  __"
           "<(o )___"
           " ( ._> /"
           "  `---'")))))
```


### 4. Animation Loop

Because Skald uses diff-based rendering, you can repeatedly call `(skald:skald ...)` inside a tight loop. It will only redraw pixels that moved, preventing the screen from flashing.

```lisp
(bifrost:with-bifrost
  (skald:skald-init :fg :black :bg :white)
  ;; Calculate a path of points from (2,2) to the center of the screen over 60 frames
  (let ((path (skald:fixed-step-line :start-row 2 
                                     :start-column 2
                                     :end-row skald:*screen-center-row* 
                                     :end-column skald:*screen-center-col*
                                     :steps-inclusive 60)))
    ;; 60fps animation
    (loop for point in path do
      (let ((r (car point))
            (c (cdr point)))
        (skald:skald
          (dotimes (i 10)
            (skald:span ((+ i 2 skald:*screen-center-row*) skald:*screen-center-col*
                         :bg :blue :fg :white :align :center)
              (make-string (- 40 (* i 2)) :initial-element #\.)))
          (skald:sprite (r c :transparant-char #\X)
             "  __"
             "<(o )___"
             "X( ._> /"
             "XX`---'"))
        (sleep 0.016))))
    (skald:skald-overlay
      (skald:span ((- skald:*screen-center-row* 4) skald:*screen-center-col* 
                   :fg :magenta :align :center)
        "Welcome to Old Norse"))
    (read-char))
```



---------

## Key concepts

### The render pipeline

Skald does not draw directly to the terminal immediately.

1.  When you call `span` or `sprite`, skald writes to an internal Change Buffer
2.  Skald keeps a copy of what is *currently* on the user's screen in a Display Buffer
3.  When the `(skald:skald ...)` body finishes, Skald compares the Change Buffer to the Display Buffer. It generates the minimal amount of ANSI escape sequences required to make the screen match the buffer.

### Coordinate system

  * **Row:** Vertical position. Starts at 1 (top).
  * **Column:** Horizontal position. Starts at 1 (left).
  * **Z-Index (Layering):** Sprites drawn later in the code appear "on top" of sprites drawn earlier. You can set a transparant character within each layer to paint composite images.

### Emojis and double-width characters

Terminals (and skald window bounding boxes) are monospaced grids, but emojis take up two grid cells. Skald automatically detects these characters to ensure alignment logic (like centering or borders) remains accurate.

-----

## API Reference

### Initialization & Control

`SKALD-INIT (&key fg bg)`
- Initializes the internal buffers based on current terminal size, clears the screen, and hides the cursor. Must be called before drawing. 
- Provide FG/BG to set terminal foreground/background colors
- Also sets these variables, describing the terminal screen, for convenience:

        *screen-height* / *screen-width*
        *screen-center-row* / *screen-center-bottom-row*
        *screen-center-col* / *screen-center-right-col*

`SKALD-CHECK-TERMINAL-SIZE ()`
- Recheck the current terminal size.

`SKALD-SYNC ()`
- Manually resizes internal buffers if the terminal window size has changed. Does not call SKALD-CHECK-TERMINAL-SIZE. You need to call that yourself, seperately.

`SKALD-CLEAR ()`
- Wipes the screen and the internal buffers. Less flicker than SKALD-INIT.

### Updating the screen

`SKALD (&body body)`
- The main macro. Code inside `body` writes to the Change Buffer. When `body` finishes, the differences are pushed to the terminal.

`SKALD-OVERLAY (&body body)`
- Similar to `SKALD`, but it does not assume the Change Buffer starts empty. Use this to draw on top of the existing frame without wiping the previous contents first.

### Layout primitives

`SPAN ((row col &key fg bg align fill-char transparant-char mask) &body subsegments)`
- Draws a single line of text.

`SPRITE (row col (&key fg bg align fill-char transparant-char mask) &body lines)`
- Draws a multi-line block of text.

### Grid layouts

`GRID ((row col &key fg bg width height align fill-char transparant-char mask border border-chars border-fg border-bg) &body columns)`
- Defines a container for columns.
  * `border`: T or NIL.
  * `border-chars`: A string of 3 chars for "Horizontal", "Vertical", and "Intersection" (e.g., `"-|+"`).

`COLUMN ((&key fg bg width height align fill-char transparant-char mask) &body windows)`
- Vertical stack of windows. Automatically placed to the right of the previous column in the grid.

`WINDOW ((&key fg bg height align fill-char transparant-char mask) &body lines)`
- A box within a column. Automatically placed below the previous window in the column.

`SOLO-WINDOW (row col (&key fg bg width height align fill-char transparant-char mask border border-chars border-fg border-bg) &body lines)`
- A window placed at absolute coordinates, outside of the Grid/Column auto-layout system.

# Mini language within SPAN/SPRITE/WINDOW/SOLO-WINDOW

Within sprite and window forms:

 * STRINGS are written to defined output
     Each string is given its own line, with newlines in the string creating additional lines
 * NULL is treated a blank line
 * CHARACTERS are treated as a single character string
     - This means that each character creates a new line when within a sprite. If you don't want each character to be treated as 1 line, put them within a :SPAN
     - NOTE: #\newline & #\return are treated as 2 blank lines
 * :NODISPLAY - the special keyword :NODISPLAY is completely ignored
 * LISTS are special forms. The CAR of the list must be one of these keywords:
      :FG (color &body forms) - everything that follows has forground COLOR
      :BG (color &body forms) - everything that follows has background COLOR
      :EMOJI (name) - inserts an emoji character; treated just like a raw character by SPAN/SPRITE
      :SPAN (&body subsegements) - everything that follows is treated as part of one line (so #\newline & #\return are forcibly removed)
      :SPRITE (&body sprites) - multi-line
      :NODISPLAY (&body anything) - everything that follows is ignored
      :CALL-WITH-POINT (fn) - calls FN with 2 arguments: the current row/col coordinates then continues processing the value returned by FN
           - if you don't want FN to show anything, then return :NODISPLAY
           - **WARNING: currently broken within non-left aligned (:CENTER / :CENTER-RIGHT / :RIGHT)**

Within spans:

 * Everthing is the same, except that anything that would produce a newline is ignored
 * It's possible for :SPAN to appear with a sprite, but not for :SPRITE to appear within a span


### Colors

Colors are passed as keywords to `:fg` and `:bg` arguments.
Available: `:black`, `:red`, `:green`, `:yellow`, `:blue`, `:magenta`, `:cyan`, `:white`.

You can define new colors with DEF-COLOR. Look them up with LOOKUP-COLOR-CODE.

### emojis

`DEF-EMOJI (name char-code)` / `LOOKUP-EMOJI (name)`
Register and use emoji by keyword.

  * Example: `(skald:span (1 1) (skald:lookup-emoji :grinning) " Hello")`

### Utilities

`FIXED-STEP-LINE (&key start-row start-column end-row end-column steps-inclusive)`
Returns a list of `(row . col)` cons cells representing a straight line path between two points. Useful for creating animation paths.


## Advanced mode stuff

`*override-terminal-size*` 
 - set this to (HEIGHT . WIDTH), & it will fool SKALD-INIT & SKALD-CHECK-TERMINAL-SIZE to using this as the terminal size. 
 - If set, skald will never query the terminal to check the actual size.

`*override-skald-drawmode*` 
 - You can set this to override the behavior of SKALD & SKALD-OVERLAY:
   * :unoptimized - Forcibly draws everything in the change. Most useful for writing unit tests, so that tests don't interfer with each other
   * :prep - Write to change buffer but don't emit. Builds up content to emit later. This is used mostly for testing.
   * :null - Write to change buffer, don't emit, then wipe the buffer. For testing.

`WITH-SKALD-TEST (&key debug-mode override-drawmode override-terminal-size) &body body)`
 - executes BODY, with the following setup:
   - captures terminal output to a string
   - attepts to read from the terminal within BODY throw an error
   - sets the following (can be overridden by keyword args):
     * sets `*OVERRIDE-SKALD-DRAWMODE*` to `:UNOPTIMIZED`
     * sets `BIFROST:*BIFROST-DEBUG-MODE*` to `:MACHINE-READABLE`
     * hard codes terminal size to (24 . 80)
 - this is for unit testing TUI screens/widgets
