



## DOCS INBOX
- SKALD-INIT - color & size
- SKALD-CHECK-SIZE, SKALD-SYNC-SIZE... resizing
- :MASK
- emojis; unrenderable-char-fill-char

## INBOX
- %MOVE-CURSOR used to call FORCE-OUTPUT. I remove it. Watch for artifacts in TTYD


```
(bifrost:with-bypass-terminal-read-buffer
  (skald:skald-init)
  (skald:skald-draw ()
    (skald:span (1 1)
     "Hello " '(:with-foreground :cyan "World") "!"))
  (sleep 0.5)
  (skald:skald-draw (:overlay)
    (skald:span (3 3) 
      "42")))

(bifrost:with-bypass-terminal-read-buffer
  (skald:skald-init)
  (skald:skald-draw ()
	  (skald:span (1 1)
	    `(:with-background :green
	      "GREEN_SPAN")))
  (sleep 1)
  (skald:skald-draw ()
	  (skald:span (1 10)
	        `(:with-background :blue
	           "BLUE_SPAN")))
  (sleep 1)
	  (skald:skald-draw ()
	    (skald:span (10 10)
	      `(:with-background :red
	        "RED_SPAN"))))
        
(labels ((%background-grid ()
           (let ((row (make-string 27 :initial-element #\.)))
		             (loop repeat 8
		                   collect row)))
	       (draw-background ()
	         (skald:sprite (1 1)
		         `(:sprite ,@(%background-grid))))
	       (draw-foreground (transparant-char)
	         (skald:sprite (2 2 :transparant-char transparant-char)
             "xxxxooooxxxxooooxxxxoooo"
	           "ooooxxxxooooxxxxooooxxxx"
	           "xxxxooooxxxxooooxxxxoooo"
	           "ooooxxxxooooxxxxooooxxxx"
	           "xxxxooooxxxxooooxxxxoooo"
	           "ooooxxxxooooxxxxooooxxxx")))
  (bifrost:with-bypass-terminal-read-buffer
    (skald:skald-init)
    (skald:skald-draw ()
      (draw-background))
    (sleep 1)
    (dolist (c '(#\x #\o))
	    (skald:skald-draw ()
        (draw-background)
  	    (draw-foreground c)
	      (sleep 1)))))
   
```




# DEVELOPMENT BACKLOG

## monitor
- [ ] look for artifacts from move cursor not calling FORCE-OUTPUT
- [ ] query-terminal-size github issue
  - [ ] if does not resolve: pull forward heroku deploy


## TODO
- [.] emojis as double width characters
  - [ ] last unit tests (double width over double width + bounding
  - [ ] split test docs?????
  - [ ] split souce code????
  - [ ] clickaround tests
- [ ] update documentation
  - [ ] sample app
- [ ] sixel support (at minimum: TTYD)
     figure out how to unify sixel + ASCII coordinate arrays
     might need need custom TTYD index.html + webfont
 [ ] additional sixel support
     - helper functions for drawing sixel from
       - file
       - array
       - geometric shape
     - ensure sixel/skald share same color code index, so don't need to
       define it in the header of every sixel image
       assume: img2sixel + assume xterm-256 colors
     - support transparancy

## ICEBOX
 * skald :mode :null
 * maybe :CENTER-LEFT  --> :CENTER
         :CENTER-RIGHT --> :CENTER-RIGHT
 * need a form like SPRITE for text that center-aligns each text line seperately
 * need a paragraph form that does word wrap
 * other styles: bold / italic / blinking / underlined / strikethrough
   (merge all style into a single metadata buffer, which is lazily created??)
 * need commands to draw a rectangles & other simple shapes
 * capture & expose the center point (y/x) of the screen for convenience??
 * ability to add outlines to sprites/spans???
 * interpolation
    * cursor should take seperate READ & ADVANCE commands?
    * curves (ease-in/ease-out/etc)
    * color transitions
    * need to be able to create a cursor with dynamic number of steps, based on how long it
      takes to move from point X1 to X2 (or Y1 Y2) moving in a straight line
 * will eventually want:
    - ROW macro (which would need ROW-GWINDOW* function) to match COLUMN macro
    - sprite vertical alignmnet
    - GWINDOW merging
    - word wrap
 * make it throw a more intuitive error when WINDOW is used within GRID instead of GWINDOW
   this is a commmon human error
 * maybe one day: maintain bounding box around change buffer changes
     in order to reduce iteration over the buffer during wipe & emit


--------------




# SKALD

"Text graphics" library for terminal emulators such as Xterm/iTerm/TTYD/Screen/SSH/etc. 
Extends BIFROST to add the following key features:

 (1) tools to work with blocks ASCII text as if they were graphical sprites
    - position, alignment, colors, transparancy, & layering

 (2) optimized screen updates for faster animations with minimal flicker
    - display/change buffer to minize writes to the screen & network IO

 (3) bells & whistles
   - windows for relative alignment, trimming, background color, borders, etc
   - window grids for easy layout or visualizing tables
   - out-of-the-box BIFROST:CBOX integration for clickable sprites/windows
   - interpolation tools to aid in animating transitions or effects

COMING SOON
 - support for emojis as double width characters
 - display images & graphics via sixel



# REQUIREMENTS

## MONOSPACED FONTS

in order for sprites, which are blocks of characters, to render correctly, you need to configure
the terminal emulator to use monospaced font a monospaced font. 

For example, here is how you do that with TTYD:
    
```
ttyd -t fontFamily="'Courier','Lucinda Console','Roboto Mono','Courier New','Monospace'" -p 8080 --writable sbcl
```

# MODERN TERMINAL

in order to use mouse tracking features, BIFROST requires the terminal emulator support XTERM
mouse tracking mode 1000 & SGR mode. This should be true for most modern terminal emulators


# NOTES: THIS README IS OUT OF DATE

(bifrost:with-bypass-terminal-read-buffer
  (skald-init)
  (skald-draw (:draw)
    (span (10 10) "Hello world!")))



# QUICKSTART

a typical skald form looks like this:

  (skald-draw (:init)
    (span (10 10) "Hello world!"))

SKALD is the main wrapper macro:
 1. does setup so that SPAN/SPRITE/WINDOW/etc can write to the change buffer
    since its mode is :INIT in this example, it resets the screen as part of that setup
 2. then updates the screen based on the change buffer

the macro SPAN writes to the change buffer. In this example it draws a single line of text
("Hello world!") at the Y/X coordinate (1/1)

SPAN is one of a number of macros that write text to the screen:
  * SPAN - writes a single line of ASCII characters
  * SPRITE - write a multi-line block of ASCII characters
  * WINDOW - defines a rectangle on the screen then writes spans/sprites inside of it
             useful for aligment, trimming, & background filling
             optional border outline
  * GRID - organize the screen into grids of windows
           useful for making tables of data or organizing the layout of the screen

here's a variation of the same example with colored text:

(bifrost:with-bypass-terminal-read-buffer
  (skald:skald-draw ()
    (skald:span (1 1)
      "Hello " '(:with-forground :blue "World") "!")))

this example writes over the previous

sometimes it's useful to clear a span/sprite using the :MASK keyword before writing the next
thing over it:

  (progn
    (skald:skald (:overlay)
      (skald:span (1 1 :mask t)
        "Hello " '(:with-forground :blue "World") "!"))
      (skald:span (1 1)
        "42")))

:MASK uses :FILL-CHAR, :FORGROUND, & :BARCKGROUND


NOTES
* within SKALD, calls to SPAN/SPRITE leave *SKALD-X*/*SKALD-Y* bound to their last coordinate
  value in order to make it easier to align the next SPAN/SPRITE to the previous one, within
  the same SKALD form



# SKALD MACRO MODES

   :INIT
      clears the screen & resets the screen dimensions (this is the only mode that does either
      of these things) then draws to the screen
   :REDRAW
      like :INIT in that it redraws the entire screen, except:
        1. it doesn't send the terminal a RESET command or check the screen size
           it just draws on the screen
        2. in order to minimize IO & unnecessary updates to the screen, it doensn't redraw
           characters that are the same in the change & display buffers
   :OVERLAY
      * doesn't try to draw/redraw the entire screen; it only draws the contents of the the
        change buffer
      * similar to :REDRAW, it skips coordinates that appear to the same in the change
        & display buffers
   :FORCE-OVERLAY
      * like :OVERLAY, except that it forcibly draws every character of the change buffer
        contents, even if the character appears to be the same in the display buffer
     * this is useful if you are writing unit tests or debugging & want to be certain exactly
       what will be written to the screen, without it being obfusicated by under the hood
       IO optimization

 NOTES:
    * SKALD :OVERLAY/:REDRAW & SPAN/SPRITE :MASK only know about updates made to the screen
      via SKALD. If you write to the screen via other means, it will break. Don't do that.
      But if you do (which you shouldn't) use :INIT/:FORCE-OVERLAY instead to clean it up
    * if, at any time, the terminal dimensions are detected to have been changed, then the
      size of the terminal & display buffers will be updated to match. This may result in the
      loss of whatever was in them. Because of that, you should do SKALD :INIT if you think
      that the size of the terminal may have changed
     



# TESTING & DEBUFFING

To debug code generating skald text graphics in the SLIME/EMACS REPL, set
`BIFROST:*RUNE-WRITE-DEBUG-MODE*` to :ESCAPE or :CONTENT. Do this either directly or by setting
the variable or the SKALD :DEBUG keyword argument

In order to unit tests the code, do the following:
  1. capture SKALD output as a string by setting :OUTPUT to NIL
  2. ensure that the the output doesn't have #\esc characters in it by setting :DEBUG to :ASCII-ESCAPE
  3. use `:FORCE-OVERLAY` mode to ensure the output isn't optimized to minize writes to the screen

Here's how that looks:
```
  (skald (:force-overlay :output nil :debug :ascii-escape) 
    ...)
```





# MINI LANGUAGE WITHIN SPAN/SPRITE/WINDOW/GWINDOW

Within sprite and window forms:

 * STRINGS are written to defined output
     Each string is given its own line, with newlines in the string creating additional lines
 * NULL is treated a blank line
 * CHARACTERS are treated as a single character string
     - This means that each character creates a new line when within a sprite
       If you don't want each character to be treated as 1 line, put them
       within a :SPAN
     - NOTE: #\newline & #\return are treated as 2 blank lines
 * :NODISPLAY - the special keyword :NODISPLAY is completely ignored
 * LISTS are special forms. The CAR of the list must be one of these keywords:
      :WITH-FORGROUND (color &rest forms)
         everything that follows has forground COLOR
      :WITH-BACKGROUND (color &rest forms)
         everything that follows has background COLOR
      :EMOJI (name)
         inserts an emoji character; treated just like a raw character by SPAN/SPRITE
      :SPAN (&rest subsegements)
         everything that follows is treated as part of one line
         (so #\newline & #\return are forcibly removed)
      :SPRITE (&rest sprites)
         multi-line
      :NODISPLAY (&rest anything)
         everything that follows is ignored
      :CALL-WITH-POINT (fn)
         calls FN with 2 arguments: the current Y/X coordinates
         then continues processing the value returned by FN
           - if you don't want FN to show anything, then return :NODISPLAY
           - WARNING: works within left-aligned WINDOW/GDWINDOW, but not non-left aligned
             (:CENTER-LEFT / :CENTER-RIGHT / :RIGHT)

Within spans:

 * Everthing is the same, except that anything that would produce a newline is ignored
 * It's possible for :SPAN to appear with a sprite, but not for :SPRITE to appear within
   a span

# COLORS

8 default colors supported out of the box:
  :black
  :blue
  :cyan
  :green
  :magenta
  :red
  :white
  :yellow

they can be used via :WITH-FORGROUND & :WITH-BACKGROUND

add more via: DEF-COLOR-CODE

# MISC NOTES

 * DRAW -> write to the buffer
 * EMIT -> write to the terminal

