




# Old Norse: development roadmap

The plan is to work through the LONG TERM ROADMAP below, while opportunistically picking off things off from the NON-ROADMAP BACKLOG section at the bottom of the document. Items in the ICEBOX are ideas I had, but I've not officially decided to do them.

This is a slow burn weekend project for me. I'm committed to the long term advancement of it. But I've also got a lot of other commitments. So please be patient about the tempo & timescale.


## LONG TERM ROADMAP

1. ~~[x] publish (v0.1.0) on GitHub~~

2. add skald/cbox integration
  - sprites/spans/windows leave behind extent variables (`*extant-min-col*`,`*extant-width*`,etc)
  - new WITH-CBOX / :CBOX forms register a cbox based on extent variables

3. spike: test TTYD on Mobile
 - understand default terminal screen size for iPhone mobile web
 - Test fonts & rendering
 - extend BIFROST:RUNE-READ should capture swipe events
 - Document playbook for (a) testing on local network (laptop<>phone on same WiFi) & (b) simple multi-region deployment with fly.io pauseable VM

4. add Sixel graphics
 - Render sixel sprites to screen
 - Figure out how to accurately map between terminal grid & sixel image heigh/width. Ensure solution works with TTYD
 - support for transparancy
 - Integrate sixel with skald buffer system for sixel-subregion diff based updates

5. add paneling feature
 - letterbox/pillarbox a rectangle in the center of the screen or within other panel
 - map between local & global screen coordinates with PANEL-ROW/PANEL-COL function
 - decide how interact with existing grid system (which is more like spreadsheet table)
 - decide whether or not to support reactive layout

6. plan basic team workflow skeleton
 - Coder needs way to stub, manage, & integrate text assets
 - ASCII artist, sixel artist, copywriter need way to update assets & test in context 
 - There is no standard for representing ASCII sprites with fg/bg color dat. Figure that out
 - Try to use existing off-the-shelf open source tools if possible

7. add option for multi-tenancy - provide a way for a single SBCL image to serve multiple active user sessions. 1:1 active user session <> SBCL thread
 - Allow Bifrost to connect to arbitrary unix socket
 - Make all old-norse functionality thread safe
 - enable multiple threads to reuse the same flokkr :async workers (assumes this feature done at this point)
 - document playbook for using nginx to load balance ttyd sessions to different sockets
 - this would be provided as *optional* capability for those who want it, to use only when needed to reduce cloud cost when scaling cloud deployment

8. Spike: reduce Gc pressure
 - items in backlog labeled **\[gc-pressure]**

............. far distant future .............

9. big hairy dream: Custom web terminal. We probably won't ever get here.
 - provide *optional* features, via web-based terminal, for users who want them:
   * control fonts & grid size from lisp
   * side load sixel sprites to speed rendering & reduce IO
   * optimize rendering on mobile
   * select grid-breaking effects: partical effects, bounce, glow, etc; maybe tweaning
 - achieve either by patching/forking TTYD or creating a custom web terminal with WASM
 
--------------------

# NON-ROADMAP BACKLOG

## shared

**\[backlog]**
 - move terminal size override logic from skald to bifrost
   * then move the non-SKALD-specific WITH-SKALD-TEST logic to WITH-BIFROST-TEST & have skald use that instead
   * then remove `skald:*output*`. There is no longer any reason for it to exist.
 - wrap all old norse tests in a single shieldwall test loader so it prints a single summary

## Flokkr

**\[backlog]**
 - Async feature feature to run slow DB queries & cloud API calls outside of the main animation loop (seperate worker thread, running CL-ASYNC to handle concurrent IO)
 - need a type of passive timer that counts up/down but doesn't trigger anything. For application specific needs (game timers) & also debounce
   * should we call it :COUNTUP/:COUNTDOWN?
   * do we need an option to switch between wallclock & virtual time (ignoring global delay)?

**\[icebox]**
 - do we need :SUBFLOKKR-DRIFT?
 - do we need a way for :INPUT clauses to yield to the next :INPUT clause?


## skald

**\[backlog]**
 - TEXT-LINES: like SPRITE that center-aligns each text line seperately
 - TEXT: like TEXT-LINES except also handles line breaking & pagination
 - more colors out of the box. maybe assume xterm-256 by default?
 - grid ROW macro as an alternative to COLUMN
 - I'm not sure :MASK is working correctly. Test it.
-  sprite vertical alignmnet

**\[gc-pressure]**
 - don't create so many PLISTS when passing around parameters
 - measuring width for left/right alignment, use a scratch array instead of strings
 - don't use FORMAT in hotpath (it allocates strings)
 - consider changing how cboxes work. For example, if we remove layering, it would allow us to use a scratch arena to make them zero alloc. would be API breaking

**\[icebox]**
 - should we support more styles: bold / italic / blinking / underlined / strikethrough?
 - %MOVE-CURSOR used to call FORCE-OUTPUT. I remove it. Watch for artifacts in TTYD
 - should we replace DEF-EMOJI with simply providing a document that maps emojis to how to write the character in lisp?
 - there are some advanced graphical effects that would become possible if we exposed the current value at terminal grid coordinates in the display & output buffers
 - should we provide the ability to add borders around sprites/spans (not just windows)?
 - interpolation helpers
   * move to a cursor model, with seperate read & advance commands
   * curves (ease-in/ease-out/etc)
   * optional color transitions
 * maybe one day: maintain bounding box around change buffer changes
     in order to reduce iteration over the buffer during wipe & emit
 
 
## bifrost

**\[backlog]**
 - Issue: sometimes there are screen artifacts printed after exiting WITH-BIFROST while the mouse is moving &  mouse tracking 1003 enabled. Perhaps this could be fixed with a small pause before FORCE-OUTPUT? but maybe it's bad to fore a pause & better to just document it as a gotcha?

**\[gc-pressure]**
  - BIFROST read buffer should use ring buffer instead of consing
  - don't use FORMAT in hotpath (it allocates strings)
  - RUNE-WRITE (currently takes a SEXP) should take a keyword followed by optional args (no consing). (BIFROST REPL debugging mode should still take a SEXP)
  - RUNE-READ (currently returns a SEXP) could either (a) will return just a keyword, saving row/col in special variables as side effect or (b) could destructively update the same cons cell (non-breaking API change)

**\[icebox]**
 - when moving terminal size check from SKALD to BIFROST, we removed tolerence of unexpected newlines in the escape sequence. I don't remember why we put that in in the first place. Watch for issue (see: BIFROST:%BIFROST-READ-ESCAPE-SEQUENCE & %READ-QUERY-CURSOR-POSITION-RESPONSE)
 - should we support mouse tracking 1001 mode, for selecting blocks of text (eg: for cut/paste)
 - TTYD stopped correctly responding to query-terminal-size on my mac. This is a TTYD issue, not a BIFROST issue, but could we provide a work around?

## Meadhorn

**\[backlog]**
- redirect `*ERROR-OUTPUT*` & `*TRACE-OUTPUT*` to same place as MEADHORN:MD
