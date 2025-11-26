

(defpackage :bifrost
  (:use :cl)
  (:export  ;; raw IO
            :*bifrost-tty-p*
            :*bifrost-io*
            :with-bifrost

            ;; writing to the terminal
            :rune-write
            :*bifrost-debug-mode*
            
            ;; reading from the terminal
            :rune-read
            :rune-read-no-hang
            :*rune*
            :*rune-name*
            :*rune-payload*

            ;; dispatching control flow based on runes
            :rune-case
            
            ;; debugging modes
            :*rune-read-debug-mode*
            :*rune-read-debug-literal-char*
              
            ;; tracking mouse events
	          :with-mouse-tracking
            :*bifrost-mouse-tracking-mode*

	          ;; defining CBOX click regions
            :with-cbox
            :register-cbox!
	          :*cbox-min-row*
            :*cbox-min-column*
	          :*cbox-max-row*
	          :*cbox-max-column*

	          ;; reading mouse click /touch screen tap events
            :cbox
      	    :cbox-p
            :cbox-name
            :cbox-identifier
            :cbox-payload
            :cbox-events
            :cbox-min-row
            :cbox-min-column
            :cbox-max-row
            :cbox-max-column
            :cbox-pressed-p
            :lookup-cbox
            :*cbox*
            :*cbox-stack*
            :*active-cbox-pressed*

            ;; advanced mode
            :rune-write-raw
            :rune-read-raw
            :rune-read-raw-no-hang
	    ))
