


(defpackage :skald-test
  (:use :cl :skald))

(in-package :skald-test)

(setf swordbreaker::*muffle-test-errors-p* nil)



;;;; clickaround test for CBOX integration
#+nil
(bifrost:with-bypass-terminal-read-buffer
  (setf skald:*skald-terminal-size-override* '(24 80))
  (bifrost:flush-rune-read-buffer)
  (bifrost:with-bifrost-mouse-tracking ()
    (bifrost:with-cbox t
      (skald:skald-init :wait-hook 'skald:skald-sync-buffer)      
      (skald:skald-draw ()
        (skald:sprite (1 1)
          "click around"
          "q to quit")
        (skald:sprite (5 10)
          "BIG TEST BUTTON")
	      (bifrost:register-cbox! :button))
      (loop
        (bifrost:rune-case (bifrost:rune-read-no-hang)
          (nil (sleep 0.1))
          ((#\q #\Q) (return :done))
          (otherwise
           (skald:skald-draw (:force-overlay)
             (skald:window (8 2 :width 40
                                :height 20
                                :border nil)
               (format nil "RUNE: ~S" bifrost:*rune*)
               (format nil "CBOX: ~S" bifrost:*cbox*)
               (format nil "CBOX-PRESSED: ~S" bifrost:*active-cbox-pressed*)
               (format nil "CBOX-STACK: ~S" bifrost:*cbox-stack*)
               ))))))))





(swordbreaker:with-test-group "SPAN, SPRITE, WINDOW, GRID"

  (swordbreaker:with-test-group "SPAN/:SPAN"
        
        ;;;; clickaround tests
        ;; do the colors look good?
        #+nil
        (skald:with-skald-test (:override-terminal-size '(24 80))
          (skald:skald-init)
          (skald:skald-draw ()
            (skald:span (3 3)
	            `(:with-background :yellow
	               "fo"
	               "o"
	               (:with-foreground  :red
	                 " bar")
	               (:with-background :black
	                 (:with-foreground  :cyan
	                   " baz "))
	               (:with-foreground  :cyan
	                 "buzz")))))


         ;;;; unit tests
        (swordbreaker:test "\\x1B[6;7Hfoobarbaz"
                           (skald:with-skald-test (:override-terminal-size '(24 80)
                                                   :debug-mode :escape-control
                                                   :output nil)
		                         (skald:skald-draw (:force-overlay)
		                           (skald:span (6 7)
		                             "foo"
		                             "bar"
		                             "baz")))
		                       :test #'equal)

        (swordbreaker:test "\\x1B[6;7Honetwothree"
                           (skald:with-skald-test (:override-terminal-size '(24 80)
                                                   :debug-mode :escape-control
                                                   :output nil)
		                         (skald:skald-draw (:force-overlay)
		                           (skald:span (6 7)
		                             (format nil "~%one~%two~%three~%"))))
		                       :test #'equal)

        (swordbreaker:test "\\x1B[43m\\x1B[6;7Hfoo\\x1B[31m bar\\x1B[37m baz\\x1B[34m buzz\\x1B[40m\\x1B[37m boof"
                           (skald:with-skald-test (:override-terminal-size '(24 80)
                                                   :debug-mode :escape-control
                                                   :output nil)
		                         (skald:skald-draw (:force-overlay)
		                           (skald:span (6 7)
		                             `(:with-background :yellow
			                              "foo"
			                             (:with-foreground  :red
			                               " bar")
			                             (:with-foreground  :white
			                               " baz")
			                             (:with-foreground  :blue
			                               " buzz"))
		                            " boof")))
		                      :test #'equal)

    ;; confirm the alignment creates a straight vertical lign
    #+nil
    (skald:with-skald-test (:override-terminal-size '(24 80))
      (skald:skald-init)
      (skald:skald-draw ()
        (skald:span (2 8) "|")
        (skald:span (3 8 :align :left) "|VEN_NUM")
        (skald:span (4 8 :align :center-left) "EVEN|NUM")
        (skald:span (5 8 :align :center-right) "EVE|_NUM")
        (skald:span (6 8 :align :right) "EVEN_NU|")
        (skald:span (7 8) "|")))

    #+nil
    (skald:with-skald-test (:override-terminal-size '(24 80))
      (skald:skald-init)
      (skald:skald-draw ()
        (skald:span (2 8) "|")
        (skald:span (3 8 :align :left) "|DD_NUM")
        (skald:span (4 8 :align :center-left) "ODD_|UM")
        (skald:span (5 8 :align :center-right) "ODD_|UM")
        (skald:span (6 8 :align :right) "ODD_NU|")
        (skald:span (7 8) "|")))


    (swordbreaker:test "\\x1B[3;9H|\\x1B[4;9H|VEN_NUM\\x1B[5;5HEVEN|NUM\\x1B[6;6HEVE|_NUM\\x1B[7;2HEVEN_NU|\\x1B[8;9H|"
                       (skald:with-skald-test (:override-terminal-size '(24 80)
                                               :debug-mode :escape-control
                                               :output nil)
		                     (skald:skald-draw (:force-overlay)
		                       (skald:span (3 9) "|")
		                       (skald:span (4 9 :align :left) "|VEN_NUM")
		                       (skald:span (5 9 :align :center-left) "EVEN|NUM")
		                       (skald:span (6 9 :align :center-right) "EVE|_NUM")
		                       (skald:span (7 9 :align :right) "EVEN_NU|")
		                       (skald:span (8 9) "|")))
		                   :test #'equal)

      (swordbreaker:test "\\x1B[3;9H|\\x1B[4;9H|DD_NUM\\x1B[5;5HODD_|UM\\x1B[6;5HODD_|UM\\x1B[7;3HODD_NU|\\x1B[8;9H|"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :escape-control
                                                 :output nil)
		                       (skald:skald-draw (:force-overlay)
		                         (skald:span (3 9) "|")
		                         (skald:span (4 9 :align :left) "|DD_NUM")
		                         (skald:span (5 9 :align :center-left) "ODD_|UM")
		                         (skald:span (6 9 :align :center-right) "ODD_|UM")
		                         (skald:span (7 9 :align :right) "ODD_NU|")
		                         (skald:span (8 9) "|")))
		                     :test #'equal)

      (swordbreaker:test '(2 4 3 13)
                         (progn
                           (skald:with-skald-test (:override-terminal-size '(24 80)
                                                   :debug-mode :escape-control
                                                   :output nil)
                             (skald:skald-draw (:force-overlay)
                               (skald:span (2 4)
                                 "123456"
                                 "789")))
                           (list bifrost:*cbox-min-row*
                                 bifrost:*cbox-min-column*
                                 bifrost:*cbox-max-row*
                                 bifrost:*cbox-max-column*))
                         :test #'equal)
    )

  (swordbreaker:with-test-group "SPRITE/:SPRITE tests"
      
      ;;;; clickaround tests
      #+nil
      (skald:with-skald-test (:override-terminal-size '(24 80))
        (skald:skald-clear)
        (skald:skald-draw ()
          (skald:sprite (3 3)
	          "today"
	          ""
	          '(:span
	            "the "
	            (:with-background :yellow
	              "yellow sun")
	            " shone on the")
	          nil
	          nil
	          `(:with-foreground :green
	             ,(format nil "green~%green grass"))
	          nil
	          '(:span
	            "above the "
	            (:with-background :blue
                (:with-foreground :cyan
	                "earth"))
	            "'s fertile top soil"))))


        ;;;; unit tests   
      (swordbreaker:test "\\x1B[6;7Hfoo\\x1B[7;7Hbar\\x1B[8;7Hbaz"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :escape-control
                                                 :output nil)
		                       (skald:skald-draw (:force-overlay)
		                         (skald:sprite (6 7)
		                           "foo"
		                           "bar"
		                           "baz")))
		                     :test #'equal)

      (equal "\\x1B[7;7Hone\\x1B[8;7Htwo\\x1B[9;7Hthree"
             "\\x1B[7;7Hone\\x1B[8;7Htwo\\x1B[9;7Hthree")
      
      (swordbreaker:test "\\x1B[7;7Hone\\x1B[8;7Htwo\\x1B[9;7Hthree"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :escape-control
                                                 :output nil)
		                       (skald:skald-draw (:force-overlay)
		                         (skald:sprite (6 7)
		                           (format nil "~%one~%two~%three~%"))))
		                     :test #'equal)
    
    (swordbreaker:test "\\x1B[9;8Hfoo\\x1B[31m\\x1B[10;8Hbar\\x1B[32mbaz\\x1B[37mbiz\\x1B[42m\\x1B[13;8Hbuz\\x1B[15;8Hzzzzz\\x1B[40m\\x1B[16;8Hnot green"
                       (skald:with-skald-test (:override-terminal-size '(24 80)
                                               :debug-mode :escape-control
                                               :output nil)
		                     (skald:skald-draw (:force-overlay)
		                       (skald:sprite (9 8)
			                       "foo"
			                       `(:span
				                          (:with-foreground :red "bar")
				                        (:with-foreground :green "baz")
				                        "biz")
			                       `(:with-background :green
				                        ,(format nil "~%~%buz~%~%zzzzz"))
			                       "not green")))
		                   :test #'equal)

    (swordbreaker:test '(2 4 3 13)
                       (progn
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :escape-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
                             (skald:sprite (2 4)
                               "123456789")))
                         (list bifrost:*cbox-min-row*
                               bifrost:*cbox-min-column*
                               bifrost:*cbox-max-row*
                               bifrost:*cbox-max-column*))
                       :test #'equal)

    (swordbreaker:test '(2 4 5 11)
                       (progn
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :escape-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
                             (skald:sprite (2 4)
                               "0"
                               "1234567"
                               "89")))
                         (list bifrost:*cbox-min-row*
                               bifrost:*cbox-min-column*
                               bifrost:*cbox-max-row*
                               bifrost:*cbox-max-column*))
                       :test #'equal)
      )
  
  (swordbreaker:with-test-group "WINDOW tests"
   
    (swordbreaker:with-test-group "WINDOW left alignment"


      ;;;; clickaround tests
      #+nil
      (skald:with-skald-test (:override-terminal-size '(24 80))
        (skald:skald-init)
        (dotimes (i 20)
          (skald:skald-draw ()
	          (skald:window (3 3 :width (- 24 i)
			                         :height 7
			                         :border t)
	            "THERE ARE 7 ROWS"
	            "red green in row 2???"
	            "row 3"
	            `(:span
	                 (:with-foreground :red "red")
	               " "
	               (:with-foreground :green "green")
	               " "
	               "in row 4")
	            (format nil "row 5~%row 6")
	            "7: there's a border"))
	        (sleep 0.5)))


        ;;;; unit tests / sprite
      (swordbreaker:test "+----------+
|foo       |
|bar       |
|baz       |
|buzz      |
|boof      |
|          |
|          |
|          |
|          |
|          |
+----------+
"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :no-control
                                                 :output nil)
		                       (skald:skald-draw (:force-overlay)
		                         (skald:window (3 3 :width 10
					                                      :height 10)
			                         "foo"
			                         `(:with-background :yellow
			                            (:with-foreground  :red
			                              "bar")
			                            (:with-foreground  :white
			                              "baz")
			                            (:with-foreground  :blue
			                              "buzz"))
			                         "boof")))
		                     :test #'equal)

      (swordbreaker:test "\\x1B[4;4H+----------+\\x1B[5;4H|foo       |\\x1B[6;4H|\\x1B[43m\\x1B[31mbar       \\x1B[40m\\x1B[37m|\\x1B[7;4H|\\x1B[43mbaz       \\x1B[40m|\\x1B[8;4H|\\x1B[43m\\x1B[34mbuzz      \\x1B[40m\\x1B[37m|\\x1B[9;4H|boof      |\\x1B[10;4H|          |\\x1B[11;4H|          |\\x1B[12;4H|          |\\x1B[13;4H|          |\\x1B[14;4H|          |\\x1B[15;4H+----------+"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :escape-control
                                                 :output nil)
		                       (skald:skald-draw (:force-overlay)
		                         (skald:window (4 4 :width 10
					                                      :height 10)
			                         "foo"
			                         `(:with-background :yellow
			                            (:with-foreground  :red
			                              "bar")
			                            (:with-foreground  :white
			                              "baz")
			                            (:with-foreground  :blue
			                              "buzz"))
			                         "boof")))
		                     :test #'equal)
      )

    (swordbreaker:with-test-group "WINDOW :FILL-CHAR"

            (swordbreaker:test "+----------+
|foo~~~~~~~|
|bar~~~~~~~|
|baz~~~~~~~|
|buzz~~~~~~|
|boof~~~~~~|
|~~~~~~~~~~|
|~~~~~~~~~~|
|~~~~~~~~~~|
|~~~~~~~~~~|
|~~~~~~~~~~|
+----------+
"
                               (skald:with-skald-test (:override-terminal-size '(24 80)
                                                       :debug-mode :no-control
                                                       :output nil)
                                 (skald:skald-draw (:force-overlay)
			                             (skald:window (4 4 :width 10
					                                            :height 10
					                                            :fill-char #\~)
			                               "foo"
			                               `(:with-background :yellow
				                                (:with-foreground  :red
				                                  "bar")
				                                (:with-foreground  :white
				                                  "baz")
				                                (:with-foreground  :blue
				                                  "buzz"))
			                               "boof")))
			                         :test #'equal)
      
                  (swordbreaker:test "+----------+
|~~~~~~foo~|
|~~~~~~bar~|
|~~~~~~baz~|
|~~~~~~buzz|
|~~~~~~boof|
|~~~~~~~~~~|
|~~~~~~~~~~|
|~~~~~~~~~~|
|~~~~~~~~~~|
|~~~~~~~~~~|
+----------+
"
                                     (skald:with-skald-test (:override-terminal-size '(24 80)
                                                             :debug-mode :no-control
                                                             :output nil)
                                       (skald:skald-draw (:force-overlay)
				                                 (skald:window (4 4 :width 10
						                                                :height 10
						                                                :fill-char #\~
						                                                :align :right)
				                                   "foo"
				                                   `(:with-background :yellow
				                                      (:with-foreground  :red
					                                      "bar")
				                                      (:with-foreground  :white
					                                      "baz")
				                                      (:with-foreground  :blue
					                                      "buzz"))
				                                   "boof")))
				                               :test #'equal)


      (swordbreaker:test "\\x1B[4;4H+----------+\\x1B[5;4H|foo~~~~~~~|\\x1B[6;4H|\\x1B[43m\\x1B[31mbar~~~~~~~\\x1B[40m\\x1B[37m|\\x1B[7;4H|\\x1B[43mbaz~~~~~~~\\x1B[40m|\\x1B[8;4H|\\x1B[43m\\x1B[34mbuzz~~~~~~\\x1B[40m\\x1B[37m|\\x1B[9;4H|boof~~~~~~|\\x1B[10;4H|~~~~~~~~~~|\\x1B[11;4H|~~~~~~~~~~|\\x1B[12;4H|~~~~~~~~~~|\\x1B[13;4H|~~~~~~~~~~|\\x1B[14;4H|~~~~~~~~~~|\\x1B[15;4H+----------+"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :escape-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
		                         (skald:window (4 4 :width 10
					                                      :height 10
					                                      :fill-char #\~)
			                         "foo"
			                         `(:with-background :yellow
			                            (:with-foreground  :red
			                              "bar")
			                            (:with-foreground  :white
			                              "baz")
			                            (:with-foreground  :blue
			                              "buzz"))
			                         "boof")))
		                       :test #'equal)
      )

    (swordbreaker:with-test-group "WINDOW right alignment"
 	  
          ;;;; clickaround tests
	        #+nil
          (skald:with-skald-test (:override-terminal-size '(24 80))
            (skald:skald-init)
	          (dotimes (i 20)
	            (skald:skald-draw ()
	              (skald:window (3 3 :width (- 24 i)
				                           :height 7
				                           :fill-char #\~
				                           :border t
				                           :align :right)
		              "THERE ARE 7 ROWS"
		              "red green in row 2???"
		              "row 3"
		              `(:span
		                   (:with-foreground :red "red")
		                 " "
		                 (:with-foreground :green "green")
		                 " "
		                 "in row 4")
		              (format nil "row 5~%row 6")
		              "7: there's a border"))
	            (sleep 0.5)))

	    (swordbreaker:test "+----------+
|     foo  |
|     baar |
|     baaaz|
|          |
|          |
+----------+
"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :no-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
			                       (skald:window (2 2 :align :right
					                                    )
			                         "foo"
			                         "baar"
			                         "baaaz")))
			                   :test #'equal)
          
	  

	  (swordbreaker:test "+------------------------+
|   THERE ARE 7 ROWS     |
|   red green in row 2???|
|   row 3                |
|   red green in row 4   |
|   row 5                |
|   row 6                |
|   7: there's a border  |
+------------------------+
"
                       (skald:with-skald-test (:override-terminal-size '(24 80)
                                               :debug-mode :no-control
                                               :output nil)
                         (skald:skald-draw (:force-overlay)
			                     (skald:window (4 4 :width 24
					                                    :height 7
					                                    :border t
					                                    :align :right)
			                       "THERE ARE 7 ROWS"
			                       "red green in row 2???"
			                       "row 3"
			                       `(:span
				                          (:with-foreground :red "red")
			                          " "
			                          (:with-foreground :green "green")
			                          " "
			                          "in row 4")
			                       (format nil "row 5~%row 6")
			                       "7: there's a border")))
			                 :test #'equal)

	    (swordbreaker:test "\\x1B[4;4H+------------------------+\\x1B[5;4H|   THERE ARE 7 ROWS     |\\x1B[6;4H|   red green in row 2???|\\x1B[7;4H|   row 3                |\\x1B[8;4H|   \\x1B[31mred\\x1B[37m \\x1B[32mgreen\\x1B[37m in row 4   |\\x1B[9;4H|   row 5                |\\x1B[10;4H|   row 6                |\\x1B[11;4H|   7: there's a border  |\\x1B[12;4H+------------------------+"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :escape-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
			                       (skald:window (4 4 :width 24
					                                      :height 7
					                                      :border t
					                                      :align :right)
			                         "THERE ARE 7 ROWS"
			                         "red green in row 2???"
			                         "row 3"
			                         `(:span
				                            (:with-foreground :red "red")
			                            " "
			                            (:with-foreground :green "green")
			                            " "
			                            "in row 4")
			                         (format nil "row 5~%row 6")
			                         "7: there's a border")))
			                 :test #'equal)

      )
      
    (swordbreaker:with-test-group "WINDOW center alignments"

          ;;;; clickaround tests
	        #+nil
          (skald:with-skald-test (:override-terminal-size '(24 80))
            (skald:skald-init)
	          (dotimes (i 20)
              (skald:skald-draw ()
	              (skald:window (3 3 :width (- 28 i)
				                           :height 7
				                           :border t
				                           :align :center-left)
		              "THERE ARE 7 ROWS"
		              "red green in row 2???"
		              "row 3"
		              `(:span
		                   (:with-foreground :red "red")
		                 " "
		                 (:with-foreground :green "green")
		                 " "
		                 "in row 4")
		              (format nil "row 5~%row 6")
		              "7: there's a border"))
	            (sleep 0.5)))


	  (swordbreaker:test "+------------------------------+
|    THERE ARE 7 ROWS          |
|    red green in row 2???     |
|    row 3                     |
|    red green in row 4        |
|    row 5                     |
|    row 6                     |
|    7: there's a border       |
+------------------------------+
"
                       (skald:with-skald-test (:override-terminal-size '(24 80)
                                               :debug-mode :no-control
                                               :output nil)
                         (skald:skald-draw (:force-overlay)
			                     (skald:window (4 4 :width 30
					                                    :height 7
					                                    :border t
					                                    :align :center-left)
			                       "THERE ARE 7 ROWS"
			                       "red green in row 2???"
			                       "row 3"
			                       `(:span
				                          (:with-foreground :red "red")
			                          " "
			                          (:with-foreground :green "green")
			                          " "
			                          "in row 4")
			                       (format nil "row 5~%row 6")
			                       "7: there's a border")))
			                 :test #'equal)

	  (swordbreaker:test "+------------+
| ARE 7 ROWS |
|reen in row |
|            |
|reen in row |
|            |
|            |
|ere's a bord|
+------------+
"
                       (skald:with-skald-test (:override-terminal-size '(24 80)
                                               :debug-mode :no-control
                                               :output nil)
                         (skald:skald-draw (:force-overlay)
			                     (skald:window (4 4 :width 12
					                                    :height 7
					                                    :border t
					                                    :align :center-left)
			                       "THERE ARE 7 ROWS"
			                       "red green in row 2???"
			                       "row 3"
			                       `(:span
				                          (:with-foreground :red "red")
			                          " "
			                          (:with-foreground :green "green")
			                          " "
			                          "in row 4")
			                       (format nil "row 5~%row 6")
			                       "7: there's a border")))
			                 :test #'equal)

	  )


    (swordbreaker:with-test-group "WINDOW foreground/background and border"


      ;;;; clickaround tests
      #+nil
      (skald:with-skald-test (:override-terminal-size '(24 80))
        (skald:skald-init)
        (skald:skald-draw ()
	        (skald:window (3 3
			                     :width 6
			                     :height 5
			                     :foreground :yellow
			                     :background :cyan
			                     :border t
			                     :border-foreground :red
			                     :border-background :blue)
	          (format nil "~%one~%two~%three~%"))))


      ;;;; unit test
      (swordbreaker:test "\\x1B[44m\\x1B[31m\\x1B[4;4H+------+\\x1B[5;4H|\\x1B[46m\\x1B[33m      \\x1B[44m\\x1B[31m|\\x1B[6;4H|\\x1B[46m\\x1B[33mone   \\x1B[44m\\x1B[31m|\\x1B[7;4H|\\x1B[46m\\x1B[33mtwo   \\x1B[44m\\x1B[31m|\\x1B[8;4H|\\x1B[46m\\x1B[33mthree \\x1B[44m\\x1B[31m|\\x1B[9;4H|\\x1B[46m\\x1B[33m      \\x1B[44m\\x1B[31m|\\x1B[10;4H+------+\\x1B[37m\\x1B[40m"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :escape-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
		                         (skald:window (4 4
				                                      :width 6
				                                      :height 5
				                                      :foreground :yellow
				                                      :background :cyan
				                                      :border t
				                                      :border-foreground :red
				                                      :border-background :blue)
			                         (format nil "~%one~%two~%three~%"))))
		                     :test #'equal)
      )


    (swordbreaker:test '(2 4 7 9)
                       (progn
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :escape-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
		                         (skald:window (2 4
				                                      :width 5
				                                      :height 5
				                                      :border nil)
                               "123456789123456789123456789"
                               "123456789123456789123456789"
                               "123456789123456789123456789"
                               "123456789123456789123456789"
                               "123456789123456789123456789"
                               "123456789123456789123456789"
                               "123456789123456789123456789")))
                         (list bifrost:*cbox-min-row*
                               bifrost:*cbox-min-column*
                               bifrost:*cbox-max-row*
                               bifrost:*cbox-max-column*))
                       :test #'equal)

    (swordbreaker:test '(2 4 9 11)
                       (progn
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :escape-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
		                         (skald:window (2 4
				                                      :width 5
				                                      :height 5
				                                      :border t)
                               "123456789123456789123456789"
                               "123456789123456789123456789"
                               "123456789123456789123456789"
                               "123456789123456789123456789"
                               "123456789123456789123456789"
                               "123456789123456789123456789"
                               "123456789123456789123456789")))
                         (list bifrost:*cbox-min-row*
                               bifrost:*cbox-min-column*
                               bifrost:*cbox-max-row*
                               bifrost:*cbox-max-column*))
                       :test #'equal)
    )


  (swordbreaker:with-test-group "GRID/COLUMN/GWINDOW"

    ;;;; clickaround tests
    #+nil
    (skald:with-skald-test (:override-terminal-size '(24 80))
      (labels ((%grid ()
	               (let ((row (make-string 20 :initial-element #\~)))
		               (loop repeat 17
		                     collect row)))
	             (draw-background ()
	               (skald:sprite (2 2)
		               `(:sprite ,@(%grid))))
	             (draw-table (&key border border-chars)
	               (skald:grid (4 4 :width 4
				                          :height 3
				                          :border border
				                          :border-chars border-chars)
		               (skald:column ()
		                 (skald:gwindow () "1")
 		                 (skald:gwindow () "2")
		                 (skald:gwindow () "3"))
		               (skald:column ()
		                 (skald:gwindow () "4")
 		                 (skald:gwindow () "5")
		                 (skald:gwindow () "6"))
		               (skald:column ()
		                 (skald:gwindow () "7")
 		                 (skald:gwindow () "8")
		                 (skald:gwindow () "9")))))
        (skald:skald-init)
        (skald:skald-draw ()
	        (draw-background))
        (sleep 1)
        (skald:skald-draw (:overlay)
	        (draw-table :border t
		                  :border-chars nil))
        (sleep 1)
        (skald:skald-draw (:overlay)
	        (draw-table :border t
		                  :border-chars "-|+)"))
        (sleep 1)
        (skald:skald-draw ()
	        (draw-background))
        (sleep 1)
        (skald:skald-draw (:overlay)
	        (draw-table :border nil))))



    (swordbreaker:with-test-group "GRID/COLUMN/GWINDOW tests"
    
      (swordbreaker:with-test-group "simple GRID/COLUMN/GWINDOW"

        (swordbreaker:test "+----+
|1   |
|    |
|    |
+----+
|2   |
|    |
|    |
+----+
|3   |
|    |
|    |
+----+
"
                           (skald:with-skald-test (:override-terminal-size '(24 80)
                                                   :debug-mode :no-control
                                                   :output nil)
                             (skald:skald-draw (:force-overlay)
		                           (skald:grid (3 3 :width 4
				                                        :height 3)
			                           (skald:column ()
			                             (skald:gwindow () "1")
 			                             (skald:gwindow () "2")
			                             (skald:gwindow () "3")))))
		                       :test #'equal)

      
        (swordbreaker:test "+----+----+----+
|1   |2   |3   |
|    |    |    |
|    |    |    |
+----+----+----+
"
                           (skald:with-skald-test (:override-terminal-size '(24 80)
                                                   :debug-mode :no-control
                                                   :output nil)
                             (skald:skald-draw (:force-overlay)
		                           (skald:grid (3 3 :width 4 :height 3)
			                           (skald:column ()
			                             (skald:gwindow () "1"))
			                           (skald:column ()
 			                             (skald:gwindow () "2"))
			                           (skald:column ()
			                             (skald:gwindow () "3")))))
		                       :test #'equal)

        (swordbreaker:test "+----+----+----+
|1   |4   |7   |
|    |    |    |
|    |    |    |
+----+----+----+
|2   |5   |8   |
|    |    |    |
|    |    |    |
+----+----+----+
|3   |6   |9   |
|    |    |    |
|    |    |    |
+----+----+----+
"
                           (skald:with-skald-test (:override-terminal-size '(24 80)
                                                   :debug-mode :no-control
                                                   :output nil)
                             (skald:skald-draw (:force-overlay)
		                           (skald:grid (5 5 :width 4 :height 3)
			                           (skald:column ()
			                             (skald:gwindow () "1")
 			                             (skald:gwindow () "2")
			                             (skald:gwindow () "3"))
			                           (skald:column ()
			                             (skald:gwindow () "4")
 			                             (skald:gwindow () "5")
			                             (skald:gwindow () "6"))
			                           (skald:column ()
			                             (skald:gwindow () "7")
 			                             (skald:gwindow () "8")
			                             (skald:gwindow () "9")))))
		                       :test #'equal)
        )

      (swordbreaker:with-test-group "GRID/COLUMN/GWINDOW with transparant border"

        (swordbreaker:test "1    4    7   
              
              
2    5    8   
              
              
3    6    9   
              
              
"
                           (skald:with-skald-test (:override-terminal-size '(24 80)
                                                   :debug-mode :no-control
                                                   :output nil)
                             (skald:skald-draw (:force-overlay)
		                           (skald:grid (5 5 :width 4
				                                        :height 3
				                                        :border t
				                                        :border-chars nil)
			                           (skald:column ()
			                             (skald:gwindow () "1")
 			                             (skald:gwindow () "2")
			                             (skald:gwindow () "3"))
			                           (skald:column ()
			                             (skald:gwindow () "4")
 			                             (skald:gwindow () "5")
			                             (skald:gwindow () "6"))
			                           (skald:column ()
			                             (skald:gwindow () "7")
 			                             (skald:gwindow () "8")
			                             (skald:gwindow () "9")))))
		                       :test #'equal)
        )

    (swordbreaker:with-test-group "GRID/COLUMN/GWINDOW without ASCII border"

      (swordbreaker:test "1   4   7   
            
            
2   5   8   
            
            
3   6   9   
            
            
"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :no-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
		                         (skald:grid (5 5 :width 4
				                                      :height 3
				                                      :border nil)
			                         (skald:column ()
			                           (skald:gwindow () "1")
 			                           (skald:gwindow () "2")
			                           (skald:gwindow () "3"))
			                         (skald:column ()
			                           (skald:gwindow () "4")
 			                           (skald:gwindow () "5")
			                           (skald:gwindow () "6"))
			                         (skald:column ()
			                           (skald:gwindow () "7")
 			                           (skald:gwindow () "8")
			                           (skald:gwindow () "9")))))
		                     :test #'equal)
      )
      )


        (swordbreaker:with-test-group ":NODISPLAY"

          ;;;; unit tests / span
          (swordbreaker:test ""
                             (skald:with-skald-test (:override-terminal-size '(24 80)
                                                     :debug-mode :escape-control
                                                     :output nil)
		                           (skald:skald-draw (:force-overlay)
		                             (skald:span (3 4)
				                           :nodisplay)))
		                         :test #'equal)

          
          (swordbreaker:test ""
                             (skald:with-skald-test (:override-terminal-size '(24 80)
                                                     :debug-mode :escape-control
                                                     :output nil)
		                           (skald:skald-draw (:force-overlay)
		                             (skald:span (3 4)
				                           '(:nodisplay "foo"))))
		                         :test #'equal)

          (swordbreaker:test "\\x1B[4;5Hfoobuz"
                             (skald:with-skald-test (:override-terminal-size '(24 80)
                                                     :debug-mode :escape-control
                                                     :output nil)
		                           (skald:skald-draw (:force-overlay)
		                             (skald:span (4 5)
			                             "foo"
			                             '(:nodisplay "bar" (:span "baz"))
			                             '(:span "buz" (:nodisplay "booze")))))
		                         :test #'equal)


       ;;;; unit tests / sprite
          (swordbreaker:test ""
                             (skald:with-skald-test (:override-terminal-size '(24 80)
                                                     :debug-mode :escape-control
                                                     :output nil)
		                           (skald:skald-draw (:force-overlay)
		                             (skald:sprite (3 4)
				                           :nodisplay)))
		                         :test #'equal)
          
          (swordbreaker:test ""
                             (skald:with-skald-test (:override-terminal-size '(24 80)
                                                     :debug-mode :escape-control
                                                     :output nil)
		                           (skald:skald-draw (:force-overlay)
		                             (skald:sprite (3 4)
				                           '(:nodisplay "foo"))))
		                         :test #'equal)

          (swordbreaker:test "\\x1B[4;5Hfoobuz"
                             (skald:with-skald-test (:override-terminal-size '(24 80)
                                                     :debug-mode :escape-control
                                                     :output nil)
		                           (skald:skald-draw (:force-overlay)
		                             (skald:span (4 5)
			                             "foo"
			                             '(:nodisplay "bar" (:span "baz"))
			                             '(:span "buz" (:nodisplay "booze")))))
		                         :test #'equal)
      )

    (swordbreaker:with-test-group ":CALL-WITH-POINT"


      (swordbreaker:test '(6 . 6)
		                     (let (point)
                           (skald:with-skald-test (:override-terminal-size '(24 80)
                                                   :debug-mode :no-control
                                                   :output nil)
                             (skald:skald-draw (:force-overlay)
			                         (skald:window (3 3
					                                      :width 10
					                                      :height 10)
			                           "foo"
			                           "bar"
			                           `(:span "ba"
			                              (:call-with-point ,(lambda (x y)
						                                             (setf point (cons x y))
						                                             :nodisplay))
			                              "z"))))
		                       point)
		                     :test #'equalp)
      
      (swordbreaker:test '((2 . 2) (2 . 4) (2 . 6) (9 . 2) (9 . 4) (9 . 6) (16 . 2) (16 . 4) (16 . 6))
		                     (let (accum)
		                       (flet ((fn (y x)
			                              (push (cons y x) accum)))
                             (skald:with-skald-test (:override-terminal-size '(24 80)
                                                     :debug-mode :no-control
                                                     :output nil)
                               (skald:skald-draw (:force-overlay)
			                           (skald:grid (1 1
					                                      :width 6
					                                      :height 1
					                                      :border t
					                                      :align :left)
			                             (skald:column ()
			                               (skald:gwindow () `(:call-with-point ,#'fn))
			                               (skald:gwindow () `(:call-with-point ,#'fn))
			                               (skald:gwindow () `(:call-with-point ,#'fn)))
			                             (skald:column ()
			                               (skald:gwindow () `(:call-with-point ,#'fn))
			                               (skald:gwindow () `(:call-with-point ,#'fn))
			                               (skald:gwindow () `(:call-with-point ,#'fn)))
			                             (skald:column ()
			                               (skald:gwindow () `(:call-with-point ,#'fn))
			                               (skald:gwindow () `(:call-with-point ,#'fn))
			                               (skald:gwindow () `(:call-with-point ,#'fn))))))
		                         (nreverse accum)))
			                   :test #'equal)
     
      )
    


    (swordbreaker:with-test-group "GRID/COLUMN/GWINDOW :ALIGN"

      (swordbreaker:test "window=15 sprite=7
+-------------+
|      |      |
+-------------+
|ODD_NU|      |
+-------------+
|   ODD|NUM   |
+-------------+
|   ODD|NUM   |
+-------------+
|      |DD_NUM|
+-------------+
|      |      |
+-------------+
"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :no-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
		                         (skald:span (1 1) "window=15 sprite=7")
		                         (skald:grid (2 1 :width 13 :height 1)
			                         (skald:column ()
			                           (skald:gwindow (:align :left)          "      |")
			                           (skald:gwindow (:align :left)          "ODD_NU|")   
			                           (skald:gwindow (:align :center-left)      "ODD|NUM")
			                           (skald:gwindow (:align :center-right)     "ODD|NUM")
			                           (skald:gwindow (:align :right)               "|DD_NUM") 
			                           (skald:gwindow (:align :right)               "|      ")))))
		                     :test #'equal)
      
      (swordbreaker:test "window=15 sprite=7
+-------------+
|      |      |
+-------------+
|ODD_NU|      |
+-------------+
|   ODD|NUM   |
+-------------+
|   ODD|NUM   |
+-------------+
|      |DD_NUM|
+-------------+
|      |      |
+-------------+
"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :no-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
		                         (skald:span (1 1) "window=15 sprite=7")
		                         (skald:grid (2 1 :width 13 :height 1)
			                         (skald:column ()
			                           (skald:gwindow (:align :left)          "      |")
			                           (skald:gwindow (:align :left)          "ODD_NU|")   
			                           (skald:gwindow (:align :center-left)      "ODD|NUM")
			                           (skald:gwindow (:align :center-right)     "ODD|NUM")
			                           (skald:gwindow (:align :right)               "|DD_NUM") 
			                           (skald:gwindow (:align :right)               "|      ")))))
		                     :test #'equal)
                         
      (swordbreaker:test "window=7 sprite=7
+-------+
|   |   |
+-------+
|ODD|NUM|
+-------+
|ODD|NUM|
+-------+
|ODD|NUM|
+-------+
|ODD|NUM|
+-------+
|   |   |
+-------+
"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :no-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
		                         (skald:span (1 1) "window=7 sprite=7")
		                         (skald:grid (2 1 :width 7 :height 1)
			                         (skald:column ()
			                           (skald:gwindow (:align :left)          "   |   ")
			                           (skald:gwindow (:align :left)          "ODD|NUM")   
			                           (skald:gwindow (:align :center-left)      "ODD|NUM")
			                           (skald:gwindow (:align :center-right)     "ODD|NUM")
			                           (skald:gwindow (:align :right)               "ODD|NUM") 
			                           (skald:gwindow (:align :right)               "   |   ")))))
		                     :test #'equal)

      (swordbreaker:test "window=5 sprite=7
+-----+
|  |  |
+-----+
|OD|_N|
+-----+
|DD|NU|
+-----+
|DD|NU|
+-----+
|D_|UM|
+-----+
|  |  |
+-----+
"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :no-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
		                         (skald:span (1 1) "window=5 sprite=7")
		                         (skald:grid (2 1 :width 5 :height 1)
			                         (skald:column ()
			                           (skald:gwindow (:align :left)          "  |    ")
			                           (skald:gwindow (:align :left)          "OD|_NUM")   
			                           (skald:gwindow (:align :center-left)      "ODD|NUM")
			                           (skald:gwindow (:align :center-right)     "ODD|NUM")
			                           (skald:gwindow (:align :right)               "ODD_|UM") 
			                           (skald:gwindow (:align :right)               "    |  ")))))
		                       :test #'equal)

    
      (swordbreaker:test "window=14 sprite=7
+--------------+
|      |       |
+--------------+
|ODD_NU|       |
+--------------+
|   ODD|NUM    |
+--------------+
|      \\       |
+--------------+
|    ODD|NUM   |
+--------------+
|       |DD_NUM|
+--------------+
|       |      |
+--------------+
"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :no-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
		                         (skald:span (1 1) "window=14 sprite=7")
		                         (skald:grid (2 1 :width 14 :height 1)
			                         (skald:column ()
			                           (skald:gwindow (:align :left)          "      |")
			                           (skald:gwindow (:align :left)          "ODD_NU|")
			                           (skald:gwindow (:align :center-left)      "ODD|NUM")
			                           (skald:gwindow (:align :left)          "      \\")
			                           (skald:gwindow (:align :center-right)     "ODD|NUM")
			                           (skald:gwindow (:align :right)               "|DD_NUM") 
			                           (skald:gwindow (:align :right)               "|      ")))))
		                     :test #'equal)

      (swordbreaker:test "window=4 sprite=7
+----+
| |  |
+----+
|O|D_|
+----+
|D|NU|
+----+
| \\  |
+----+
|DD|N|
+----+
|_N|M|
+----+
|  | |
+----+
"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :no-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
		                         (skald:span (1 1) "window=4 sprite=7")
		                         (skald:grid (2 1 :width 4 :height 1)
			                         (skald:column ()
			                           (skald:gwindow (:align :left)            " |     ")
			                           (skald:gwindow (:align :left)            "O|D_NUM")
			                           (skald:gwindow (:align :center-left)   "ODD|NUM")
			                           (skald:gwindow (:align :left)            " \\     ")
			                           (skald:gwindow (:align :center-right)  "ODD|NUM")
			                           (skald:gwindow (:align :right)       "ODD_N|M") 
			                           (skald:gwindow (:align :right)        "    | ")))))
		                     :test #'equal)


   
      (swordbreaker:test "window=16 sprite=8
+----------------+
|       |        |
+----------------+
|EVEN_NU|        |
+----------------+
|    EVE|_NUM    |
+----------------+
|       \\        |
+----------------+
|    EVEN|NUM    |
+----------------+
|        |VEN_NUM|
+----------------+
|        |       |
+----------------+
"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :no-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
		                         (skald:span (1 1) "window=16 sprite=8")
		                         (skald:grid (2 1 :width 16 :height 1)
			                         (skald:column ()
			                           (skald:gwindow (:align :left)         "       |")
			                           (skald:gwindow (:align :left)         "EVEN_NU|")
			                           (skald:gwindow (:align :center-left)     "EVE|_NUM")
			                           (skald:gwindow (:align :left)         "       \\")
			                           (skald:gwindow (:align :center-right)      "EVEN|NUM")
			                           (skald:gwindow (:align :right)               "|VEN_NUM")
			                           (skald:gwindow (:align :right)               "|       ")))))
		                     :test #'equal)
      
      (swordbreaker:test "window=8 sprite=8
+--------+
|   |    |
+--------+
|EVE|_NUM|
+--------+
|EVE|_NUM|
+--------+
|EVE|_NUM|
+--------+
|EVE|_NUM|
+--------+
|   |    |
+--------+
"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :no-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
		                         (skald:span (1 1) "window=8 sprite=8")
		                         (skald:grid (2 1 :width 8 :height 1)
			                         (skald:column ()
			                           (skald:gwindow (:align :left)         "   |    ")
			                           (skald:gwindow (:align :left)         "EVE|_NUM")
			                           (skald:gwindow (:align :center-left)  "EVE|_NUM")
			                           (skald:gwindow (:align :center-right) "EVE|_NUM")
			                           (skald:gwindow (:align :right)        "EVE|_NUM")
			                           (skald:gwindow (:align :right)        "   |    ")))))
		                     :test #'equal)
      
      (swordbreaker:test "window=4 sprite=8
+----+
| |  |
+----+
|E|EN|
+----+
|E|_N|
+----+
| \\  |
+----+
|EN|N|
+----+
|_N|M|
+----+
|  | |
+----+
"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :no-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
		                         (skald:span (1 1) "window=4 sprite=8")
		                         (skald:grid (2 1 :width 4 :height 1)
			                         (skald:column ()
			                           (skald:gwindow (:align :left)              " |      ")
			                           (skald:gwindow (:align :left)              "E|EN_NUM")
			                           (skald:gwindow (:align :center-left)     "EVE|_NUM")
			                           (skald:gwindow (:align :left)              " \\     ")
			                           (skald:gwindow (:align :center-right)   "EVEN|NUM")
			                           (skald:gwindow (:align :right)        "EVEN_N|M")
			                           (skald:gwindow (:align :right)        "      | ")))))
		                     :test #'equal)
		    
      (swordbreaker:test "+-----------------+
|       |         |
+-----------------+
|EVEN_NU|         |
+-----------------+
|    EVE|_NUM     |
+-----------------+
|       \\         |
+-----------------+
|         \\       |
+-----------------+
|     EVEN|NUM    |
+-----------------+
|         |VEN_NUM|
+-----------------+
|         |       |
+-----------------+
"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :no-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
		                         (skald:grid (2 1 :width 17 :height 1)
			                         (skald:column ()
			                           (skald:gwindow (:align :left)         "       |")
			                           (skald:gwindow (:align :left)         "EVEN_NU|")
			                           (skald:gwindow (:align :center-left)     "EVE|_NUM")
			                           (skald:gwindow (:align :left)         "       \\")
			                           (skald:gwindow (:align :right)        "\\       ")
			                           (skald:gwindow (:align :center-right)      "EVEN|NUM")
			                           (skald:gwindow (:align :right)               "|VEN_NUM")
			                           (skald:gwindow (:align :right)               "|       ")))))
		                     :test #'equal)
      
      (swordbreaker:test "window=5 sprite=8
+-----+
|  |  |
+-----+
|EV|N_|
+-----+
|EN|NU|
+-----+
|VE|_N|
+-----+
|N_|UM|
+-----+
|  |  |
+-----+
"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :no-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
		                         (skald:span (1 1) "window=5 sprite=8")
		                         (skald:grid (2 1 :width 5 :height 1)
			                         (skald:column ()
			                           (skald:gwindow (:align :left)         "  |     ")
			                           (skald:gwindow (:align :left)         "EV|N_NUM")
			                           (skald:gwindow (:align :center-left)     "EVEN|NUM")
			                           (skald:gwindow (:align :center-right)      "EVE|_NUM")
			                           (skald:gwindow (:align :right)               "EVEN_|UM")
			                           (skald:gwindow (:align :right)               "     |  ")))))
		                     :test #'equal)


    
      )

    
    )


  
    (swordbreaker:with-test-group ":TRANSPARANT-CHAR"

    ;;;; clickaround tests
      #+nil
      (skald:with-skald-test (:override-terminal-size '(24 80))
        (labels ((%background-grid ()
	                 (let ((row (make-string 27 :initial-element #\.)))
		                 (loop repeat 8
		                       collect row)))
	               (draw-background ()
	                 (skald:sprite (1 1)
		                 `(:sprite ,@(%background-grid))))
	               (draw-foreground (transparant-char)
	                 (skald:sprite (2 2
				                            :transparant-char transparant-char)
		                 "xxxxooooxxxxooooxxxxoooo"
		                 "ooooxxxxooooxxxxooooxxxx"
		                 "xxxxooooxxxxooooxxxxoooo"
		                 "ooooxxxxooooxxxxooooxxxx"
		                 "xxxxooooxxxxooooxxxxoooo"
		                 "ooooxxxxooooxxxxooooxxxx")))
          (skald:skald-init)
          (skald:skald-draw ()
	          (draw-background))
          (sleep 1)
          (dolist (c '(#\x #\o))
	          (skald:skald-draw ()
	            (draw-background)
	            (draw-foreground c))
	          (sleep 1))))
      
      #+nil
      (skald:with-skald-test (:override-terminal-size '(24 80))
        (flet ((draw-background ()
	               (let* ((row (make-string 22 :initial-element #\.))
		                    (rectangle (loop repeat 16
				                                 collect row)))
	                 (skald:sprite (2 2)
		                 `(:sprite ,@rectangle))))
	             (draw-table (transparant-char)
	               (skald:window (4 4
			                            :width 16
			                            :height 10
			                            :fill-char #\~
			                            :transparant-char transparant-char
			                            :foreground :cyan
			                            :background :blue
			                            :border t
			                            :border-foreground :black
			                            :border-background :white
			                            :align :center-left)
	                 (format nil "~%entertain~%three~%educated~%elephants~%"))))
          (skald:skald-init)
          (dolist (c '(#\nul #\e #\~))
	          (skald:skald-draw ()
	            (draw-background))
	          (sleep 1)
	          (skald:skald-draw (:overlay)
	            (draw-table c))
	          (sleep 2))))
	    
    ;;;; unit tests
    (swordbreaker:test "\\x1B[44m\\x1B[31m\\x1B[5;5H+----------------+\\x1B[6;5H|\\x1B[46m\\x1B[33m~~~~~~~~~~~~~~~~\\x1B[44m\\x1B[31m|\\x1B[7;5H|\\x1B[46m\\x1B[33m~~~~\\x1B[7;11Hnt\\x1B[7;14Hrtain~~~\\x1B[44m\\x1B[31m|\\x1B[8;5H|\\x1B[46m\\x1B[33m~~~~thr\\x1B[8;15H~~~~~~~\\x1B[44m\\x1B[31m|\\x1B[9;5H|\\x1B[46m\\x1B[33m~~~~\\x1B[9;11Hducat\\x1B[9;17Hd~~~~\\x1B[44m\\x1B[31m|\\x1B[10;5H|\\x1B[46m\\x1B[33m~~~~\\x1B[10;11Hl\\x1B[10;13Hphants~~~\\x1B[44m\\x1B[31m|\\x1B[11;5H|\\x1B[46m\\x1B[33m~~~~~~~~~~~~~~~~\\x1B[44m\\x1B[31m|\\x1B[12;5H|\\x1B[46m\\x1B[33m~~~~~~~~~~~~~~~~\\x1B[44m\\x1B[31m|\\x1B[13;5H|\\x1B[46m\\x1B[33m~~~~~~~~~~~~~~~~\\x1B[44m\\x1B[31m|\\x1B[14;5H|\\x1B[46m\\x1B[33m~~~~~~~~~~~~~~~~\\x1B[44m\\x1B[31m|\\x1B[15;5H|\\x1B[46m\\x1B[33m~~~~~~~~~~~~~~~~\\x1B[44m\\x1B[31m|\\x1B[16;5H+----------------+\\x1B[37m\\x1B[40m"
		                   (let ((transparant-char #\e))
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :escape-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
		                         (skald:window (5 5
				                                      :width 16
				                                      :height 10
				                                      :fill-char #\~
				                                      :transparant-char transparant-char
				                                      :foreground :yellow
				                                      :background :cyan
				                                      :border t
				                                      :border-foreground :red
				                                      :border-background :blue
				                                      :align :center-left)
			                         (format nil "~%entertain~%three~%educated~%elephants~%")))))
		                   :test #'equal)
      
    (swordbreaker:test "\\x1B[44m\\x1B[31m\\x1B[5;5H+----------------+\\x1B[6;5H|\\x1B[6;22H|\\x1B[7;5H|\\x1B[46m\\x1B[33m\\x1B[7;9Hentertain\\x1B[44m\\x1B[31m\\x1B[7;22H|\\x1B[8;5H|\\x1B[46m\\x1B[33m\\x1B[8;9Hthree\\x1B[44m\\x1B[31m\\x1B[8;22H|\\x1B[9;5H|\\x1B[46m\\x1B[33m\\x1B[9;9Heducated\\x1B[44m\\x1B[31m\\x1B[9;22H|\\x1B[10;5H|\\x1B[46m\\x1B[33m\\x1B[10;9Helephants\\x1B[44m\\x1B[31m\\x1B[10;22H|\\x1B[11;5H|\\x1B[11;22H|\\x1B[12;5H|\\x1B[12;22H|\\x1B[13;5H|\\x1B[13;22H|\\x1B[14;5H|\\x1B[14;22H|\\x1B[15;5H|\\x1B[15;22H|\\x1B[16;5H+----------------+\\x1B[37m\\x1B[40m"
		                   (let ((transparant-char #\~))
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :escape-control
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
		                         (skald:window (5 5
				                                      :width 16
				                                      :height 10
				                                      :fill-char #\~
				                                      :transparant-char transparant-char
				                                      :foreground :yellow
				                                      :background :cyan
				                                      :border t
				                                      :border-foreground :red
				                                      :border-background :blue
				                                      :align :center-left)
			                         (format nil "~%entertain~%three~%educated~%elephants~%")))))
		                   :test #'equal)
      )


  (swordbreaker:with-test-group "FIXED-STEP-LINE"

    (swordbreaker:test '((1 . 1) (1 . 2) (2 . 4) (3 . 6) (4 . 8) (5 . 10))
		                   (skald:fixed-step-line :start-row 1
					                                    :start-column 1
					                                    :steps-inclusive 5
					                                    :end-row 5
					                                    :end-column 10)
		                   :test #'equal)
    )
				


  (swordbreaker:with-test-group ":MASK"

    ;;;; clickaround tests
    #+ nil
    (skald:with-skald-test (:override-terminal-size '(24 80))
      (flet ((draw (xx &optional mask)
	             (skald:span (3 10 :mask mask
			                           :align :center-left)
	               xx)))
        (skald:skald-init)
        (skald:skald-draw () (draw "FOOBARBAZ"))
        (sleep 1)
        (skald:skald-draw (:overlay) (draw "FOOBARBAZ" t))
        (sleep 1)
        (skald:skald-draw (:overlay) (draw "foo"))
        (sleep 1)
        (skald:skald-draw (:overlay) (draw "foo" t))
        (sleep 1)))

    #+ nil
    (skald:with-skald-test (:override-terminal-size '(24 80))
      (flet ((draw (xx &optional mask)
	             (skald:span (3 10 :mask mask
			                           :align :center-left)
	               xx)))
        (skald:skald-init)
        (skald:skald-draw () (draw "FOOBARBAZ"))
        (sleep 1)
        (skald:skald-draw (:prep) (draw "FOOBARBAZ" t))
        (sleep 1)
        (skald:skald-draw (:overlay) (draw "foo"))
        (sleep 1)))
    
    #+ nil
    (skald:with-skald-test (:override-terminal-size '(24 80))
      (let ((xx '(:span
		              "FOO"
		              (:with-foreground :blue "BLUE")
		              #\&
		              (:with-background :white
		                (:with-foreground :red
		                  "RED"))
		              "BAR")))
        (skald:skald-init)
        (skald:skald-draw ()
	        (skald:span (3 15 :align :center-left
			                      :foreground :white
			                      :background :black)
	          xx))
        (sleep 1)
        (skald:skald-draw (:force-overlay)
	        (skald:span (3 15 :mask t
		                        :fill-char #\x
			                      :align :center-left
			                      :foreground :cyan
			                      :background :black)
	          xx))
        (sleep 1)))



    
    ;; unit tests
    (swordbreaker:test "xxx
"
                       (skald:with-skald-test (:override-terminal-size '(24 80)
                                               :debug-mode :no-control
                                               :output nil)
                         (skald:skald-draw (:force-overlay)
			                     (skald:span (1 1 :mask t :fill-char #\x)
			                       "foo")))
		                   :test #'equal)
    
    )
  )
