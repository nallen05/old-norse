


(defpackage :skald-test
  (:use :cl :skald))

(in-package :skald-test)

;; (setf shieldwall::*shieldwall-suppress-errors-p* nil)


;;;; clickaround test for CBOX integration
#+nil
(bifrost:with-bifrost
  (bifrost:with-mouse-tracking (1000)
    (skald:skald-init)
    (bifrost:with-cbox-layer :new
      (bifrost:register-cbox! :button 5 10 6 25)
      (loop do
        (case bifrost:*rune*
          ((#\q #\Q) (return :done))
          (otherwise
           (skald:skald
             (skald:sprite (1 1)
               "click around"
               "q to quit")
             (skald:sprite (5 10)
               "BIG TEST BUTTON")
             (skald:solo-window (8 2 :width 40
                                     :height 20
                                     :border nil)
               (format nil "RUNE: ~S" bifrost:*rune*)
               (format nil "RUNE-CONTAINER: ~S" bifrost:*rune-container*)
               (format nil "PRESSED-CBOX: ~S" bifrost:*pressed-cbox*)))
           (bifrost:rune-read)))))))



(shieldwall:with-shield-group "SPAN, SPRITE, WINDOW, GRID"

  (shieldwall:with-shield-group "SPAN/:SPAN"
        
        ;;;; clickaround tests
        ;; do the colors look good?
        #+nil
        (bifrost:with-bifrost
          (skald:skald-init)
          (skald:skald ()
            (skald:span (3 3)
	            `(:bg :yellow
	               "fo"
	               "o"
	               (:fg  :red
	                 " bar")
	               (:bg :black
	                 (:fg  :cyan
	                   " baz "))
	               (:fg  :cyan
	                 "buzz")))))

    
    ;;;; unit tests
    (shieldwall:shield "span as strings"
                       "\\x1B[6;7Hfoobarbaz"
                       (skald:with-skald-test ()
		                     (skald:skald
		                       (skald:span (6 7)
		                         "foo"
		                         "bar"
		                         "baz"))))

    (shieldwall:shield "span as newlines"
                       "\\x1B[6;7Honetwothree"
                       (skald:with-skald-test ()
		                     (skald:skald
		                       (skald:span (6 7)
		                         (format nil "~%one~%two~%three~%")))))

    (shieldwall:shield "span with colors"
                       "\\x1B[43m\\x1B[6;7Hfoo\\x1B[31m bar\\x1B[37m baz\\x1B[34m buzz\\x1B[40m\\x1B[37m boof"
                       (skald:with-skald-test ()
		                         (skald:skald
		                           (skald:span (6 7)
		                             `(:bg :yellow
			                              "foo"
			                             (:fg  :red
			                               " bar")
			                             (:fg  :white
			                               " baz")
			                             (:fg  :blue
			                               " buzz"))
		                            " boof"))))

    ;; confirm the alignment creates a straight vertical lign
    #+nil
    (bifrost:with-bifrost
      (skald:skald-init)
      (skald:skald ()
        (skald:span (2 8) "|")
        (skald:span (3 8 :align :left) "|VEN_NUM")
        (skald:span (4 8 :align :center-left) "EVEN|NUM")
        (skald:span (5 8 :align :center-right) "EVE|_NUM")
        (skald:span (6 8 :align :right) "EVEN_NU|")
        (skald:span (7 8) "|")))

    #+nil
    (bifrost:with-bifrost
      (skald:skald-init)
      (skald:skald ()
        (skald:span (2 8) "|")
        (skald:span (3 8 :align :left) "|DD_NUM")
        (skald:span (4 8 :align :center-left) "ODD_|UM")
        (skald:span (5 8 :align :center-right) "ODD_|UM")
        (skald:span (6 8 :align :right) "ODD_NU|")
        (skald:span (7 8) "|")))


    (shieldwall:shield "span alignment (even width)"
                       "\\x1B[3;9H|\\x1B[4;9H|VEN_NUM\\x1B[5;5HEVEN|NUM\\x1B[6;6HEVE|_NUM\\x1B[7;2HEVEN_NU|\\x1B[8;9H|"
                       (skald:with-skald-test ()
		                     (skald:skald
		                       (skald:span (3 9) "|")
		                       (skald:span (4 9 :align :left) "|VEN_NUM")
		                       (skald:span (5 9 :align :center-left) "EVEN|NUM")
		                       (skald:span (6 9 :align :center-right) "EVE|_NUM")
		                       (skald:span (7 9 :align :right) "EVEN_NU|")
		                       (skald:span (8 9) "|"))))

    (shieldwall:shield "span alignment (odd width)"
                       "\\x1B[3;9H|\\x1B[4;9H|DD_NUM\\x1B[5;5HODD_|UM\\x1B[6;5HODD_|UM\\x1B[7;3HODD_NU|\\x1B[8;9H|"
                       (skald:with-skald-test ()
		                     (skald:skald
		                       (skald:span (3 9) "|")
		                       (skald:span (4 9 :align :left) "|DD_NUM")
		                       (skald:span (5 9 :align :center-left) "ODD_|UM")
		                       (skald:span (6 9 :align :center-right) "ODD_|UM")
		                       (skald:span (7 9 :align :right) "ODD_NU|")
		                       (skald:span (8 9) "|"))))
    #+nil
    (shieldwall:shield "SPAN leaves behind \"extent\" variables"
                       '(2 4 3 13)
                       (progn
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :machine-readable
                                                 :output nil)
                           (skald:skald
                             (skald:span (2 4)
                               "123456"
                               "789")))
                         (list skald:*extant-min-row*
                               skald:*extant-min-col*
                               skald:*extant-max-row*
                               skald:*extant-max-col*)))
    )

  (shieldwall:with-shield-group "SPRITE/:SPRITE tests"
      
      ;;;; clickaround tests
      #+nil
      (bifrost:with-bifrost
        (skald:skald-clear)
        (skald:skald ()
          (skald:sprite (3 3)
	          "today"
	          ""
	          '(:span
	            "the "
	            (:bg :yellow
	              "yellow sun")
	            " shone on the")
	          nil
	          nil
	          `(:fg :green
	             ,(format nil "green~%green grass"))
	          nil
	          '(:span
	            "above the "
	            (:bg :blue
                (:fg :cyan
	                "earth"))
	            "'s fertile top soil"))))


        ;;;; unit tests   
    (shieldwall:shield "sprite as strings"
                       "\\x1B[6;7Hfoo\\x1B[7;7Hbar\\x1B[8;7Hbaz"
                       (skald:with-skald-test ()
		                       (skald:skald
		                         (skald:sprite (6 7)
		                           "foo"
		                           "bar"
		                           "baz"))))

    (shieldwall:shield "sprite as newlines"
     "\\x1B[7;7Hone\\x1B[8;7Htwo\\x1B[9;7Hthree"
                       (skald:with-skald-test ()
		                     (skald:skald
		                       (skald:sprite (6 7)
		                         (format nil "~%one~%two~%three~%")))))
    
    (shieldwall:shield "sprite with colors"
                       "\\x1B[9;8Hfoo\\x1B[31m\\x1B[10;8Hbar\\x1B[32mbaz\\x1B[37mbiz\\x1B[42m\\x1B[13;8Hbuz\\x1B[15;8Hzzzzz\\x1B[40m\\x1B[16;8Hnot green"
                       (skald:with-skald-test ()
		                     (skald:skald
		                       (skald:sprite (9 8)
			                       "foo"
			                       `(:span
				                          (:fg :red "bar")
				                        (:fg :green "baz")
				                        "biz")
			                       `(:bg :green
				                        ,(format nil "~%~%buz~%~%zzzzz"))
			                       "not green"))))
#+nil
    (shieldwall:shield "SPRITE leaves behind \"extent\" variables (test 1/2)"
                       '(1 4 2 13)
                       (progn
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :machine-readable
                                                 :output nil)
                           (skald:skald
                             (skald:sprite (1 4)
                               "123456789")))
                         (list skald:*extant-min-row*
                               skald:*extant-min-col*
                               skald:*extant-max-row*
                               skald:*extant-max-col*)))
#+nil
    (shieldwall:shield "SPRITE leaves behind \"extent\" variables (test 2/2)"
                       '(2 5 5 13)
                       (progn
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :machine-readable
                                                 :output nil)
                           (skald:skald
                             (skald:sprite (2 4)
                               "0"
                               "1234567"
                               "89")))
                         (list skald:*extant-min-row*
                               skald:*extant-min-col*
                               skald:*extant-max-row*
                               skald:*extant-max-col*)))
    )
  
  (shieldwall:with-shield-group "SOLO-WINDOW tests"
   
    (shieldwall:with-shield-group "SOLO-WINDOW left alignment"


      ;;;; clickaround tests
      #+nil
      (bifrost:with-bifrost
        (skald:skald-init)
        (dotimes (i 20)
          (skald:skald ()
	          (skald:solo-window (3 3 :width (- 24 i)
			                              :height 7
			                              :border t)
	            "THERE ARE 7 ROWS"
	            "red green in row 2???"
	            "row 3"
	            `(:span
	                 (:fg :red "red")
	               " "
	               (:fg :green "green")
	               " "
	               "in row 4")
	            (format nil "row 5~%row 6")
	            "7: there's a border"))
	        (sleep 0.5)))


        ;;;; unit tests / sprite
      (shieldwall:shield "SOLO-WINDOW :HUMAN-READABLE"
                         "+----------+
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
                         (skald:with-skald-test (:debug-mode :human-readable)
		                       (skald:skald
		                         (skald:solo-window (3 3 :width 10
					                                           :height 10)
			                         "foo"
			                         `(:bg :yellow
			                            (:fg  :red
			                              "bar")
			                            (:fg  :white
			                              "baz")
			                            (:fg  :blue
			                              "buzz"))
			                         "boof"))))

      (shieldwall:shield "SOLO-WINDOW :MACHINE-READABLE"
                         "\\x1B[4;4H+----------+\\x1B[5;4H|foo       |\\x1B[6;4H|\\x1B[43m\\x1B[31mbar       \\x1B[40m\\x1B[37m|\\x1B[7;4H|\\x1B[43mbaz       \\x1B[40m|\\x1B[8;4H|\\x1B[43m\\x1B[34mbuzz      \\x1B[40m\\x1B[37m|\\x1B[9;4H|boof      |\\x1B[10;4H|          |\\x1B[11;4H|          |\\x1B[12;4H|          |\\x1B[13;4H|          |\\x1B[14;4H|          |\\x1B[15;4H+----------+"
                         (skald:with-skald-test ()
		                       (skald:skald
		                         (skald:solo-window (4 4 :width 10
					                                           :height 10)
			                         "foo"
			                         `(:bg :yellow
			                            (:fg  :red
			                              "bar")
			                            (:fg  :white
			                              "baz")
			                            (:fg  :blue
			                              "buzz"))
			                         "boof"))))

    (shieldwall:with-shield-group "SOLO-WINDOW :FILL-CHAR"

      (shieldwall:shield ":FILL-CHAR window left alignment"
                         "+----------+
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
                         (skald:with-skald-test (:debug-mode :human-readable)
                           (skald:skald
			                       (skald:solo-window (4 4 :width 10
					                                           :height 10
					                                           :fill-char #\~)
			                         "foo"
			                         `(:bg :yellow
				                          (:fg  :red
				                            "bar")
				                          (:fg  :white
				                            "baz")
				                          (:fg  :blue
				                            "buzz"))
			                         "boof"))))
      
      (shieldwall:shield ":FILL-CHAR window right alignment"
                         "+----------+
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
                         (skald:with-skald-test (:debug-mode :human-readable)
                           (skald:skald
				                     (skald:solo-window (4 4 :width 10
						                                         :height 10
						                                         :fill-char #\~
						                                         :align :right)
				                       "foo"
				                       `(:bg :yellow
				                          (:fg  :red
					                          "bar")
				                          (:fg  :white
					                          "baz")
				                          (:fg  :blue
					                          "buzz"))
				                       "boof"))))


      (shieldwall:shield ":FILL-CHAR window :MACHINE-READABLE"
                         "\\x1B[4;4H+----------+\\x1B[5;4H|foo~~~~~~~|\\x1B[6;4H|\\x1B[43m\\x1B[31mbar~~~~~~~\\x1B[40m\\x1B[37m|\\x1B[7;4H|\\x1B[43mbaz~~~~~~~\\x1B[40m|\\x1B[8;4H|\\x1B[43m\\x1B[34mbuzz~~~~~~\\x1B[40m\\x1B[37m|\\x1B[9;4H|boof~~~~~~|\\x1B[10;4H|~~~~~~~~~~|\\x1B[11;4H|~~~~~~~~~~|\\x1B[12;4H|~~~~~~~~~~|\\x1B[13;4H|~~~~~~~~~~|\\x1B[14;4H|~~~~~~~~~~|\\x1B[15;4H+----------+"
                         (skald:with-skald-test (:debug-mode :machine-readable)
                           (skald:skald
		                         (skald:solo-window (4 4 :width 10
					                                           :height 10
					                                           :fill-char #\~)
			                         "foo"
			                         `(:bg :yellow
			                            (:fg  :red
			                              "bar")
			                            (:fg  :white
			                              "baz")
			                            (:fg  :blue
			                              "buzz"))
			                         "boof"))))
      )

    (shieldwall:with-shield-group "window right alignment"
 	  
          ;;;; clickaround tests
	        #+nil
          (bifrost:with-bifrost
            (skald:skald-init)
	          (dotimes (i 20)
	            (skald:skald ()
	              (skald:solo-window (3 3 :width (- 24 i)
				                                :height 7
				                                :fill-char #\~
				                                :border t
				                                :align :right)
		              "THERE ARE 7 ROWS"
		              "red green in row 2???"
		              "row 3"
		              `(:span
		                   (:fg :red "red")
		                 " "
		                 (:fg :green "green")
		                 " "
		                 "in row 4")
		              (format nil "row 5~%row 6")
		              "7: there's a border"))
	            (sleep 0.5)))

	    (shieldwall:shield "window right alignment 1"
                         "+----------+
|     foo  |
|     baar |
|     baaaz|
|          |
|          |
+----------+
"
                         (skald:with-skald-test (:debug-mode :human-readable)
                           (skald:skald
			                       (skald:solo-window (2 2 :align :right)
			                         "foo"
			                         "baar"
			                         "baaaz"))))
          
	  

	    (shieldwall:shield "widow right alignment 2"
                         "+------------------------+
|   THERE ARE 7 ROWS     |
|   red green in row 2???|
|   row 3                |
|   red green in row 4   |
|   row 5                |
|   row 6                |
|   7: there's a border  |
+------------------------+
"
                         (skald:with-skald-test (:debug-mode :human-readable)
                           (skald:skald
			                       (skald:solo-window (4 4 :width 24
					                                           :height 7
					                                           :border t
					                                           :align :right)
			                         "THERE ARE 7 ROWS"
			                         "red green in row 2???"
			                         "row 3"
			                         `(:span
				                            (:fg :red "red")
			                            " "
			                            (:fg :green "green")
			                            " "
			                            "in row 4")
			                         (format nil "row 5~%row 6")
			                         "7: there's a border"))))

	    (shieldwall:shield "widow right alignment :MACHINE-READABLE"
                         "\\x1B[4;4H+------------------------+\\x1B[5;4H|   THERE ARE 7 ROWS     |\\x1B[6;4H|   red green in row 2???|\\x1B[7;4H|   row 3                |\\x1B[8;4H|   \\x1B[31mred\\x1B[37m \\x1B[32mgreen\\x1B[37m in row 4   |\\x1B[9;4H|   row 5                |\\x1B[10;4H|   row 6                |\\x1B[11;4H|   7: there's a border  |\\x1B[12;4H+------------------------+"
                         (skald:with-skald-test ()
                           (skald:skald
			                       (skald:solo-window (4 4 :width 24
					                                           :height 7
					                                           :border t
					                                           :align :right)
			                         "THERE ARE 7 ROWS"
			                         "red green in row 2???"
			                         "row 3"
			                         `(:span
				                            (:fg :red "red")
			                            " "
			                            (:fg :green "green")
			                            " "
			                            "in row 4")
			                         (format nil "row 5~%row 6")
			                         "7: there's a border"))))
      
      )
      
    (shieldwall:with-shield-group "window center alignments"

          ;;;; clickaround tests
	        #+nil
          (bifrost:with-bifrost
            (skald:skald-init)
	          (dotimes (i 20)
              (skald:skald ()
	              (skald:solo-window (3 3 :width (- 28 i)
				                                :height 7
				                                :border t
				                                :align :center-left)
		              "THERE ARE 7 ROWS"
		              "red green in row 2???"
		              "row 3"
		              `(:span
		                   (:fg :red "red")
		                 " "
		                 (:fg :green "green")
		                 " "
		                 "in row 4")
		              (format nil "row 5~%row 6")
		              "7: there's a border"))
	            (sleep 0.5)))


	    (shieldwall:shield "window center aligment 1"
                         "+------------------------------+
|    THERE ARE 7 ROWS          |
|    red green in row 2???     |
|    row 3                     |
|    red green in row 4        |
|    row 5                     |
|    row 6                     |
|    7: there's a border       |
+------------------------------+
"
                         (skald:with-skald-test (:debug-mode :human-readable)
                           (skald:skald
			                       (skald:solo-window (4 4 :width 30
					                                           :height 7
					                                           :border t
					                                           :align :center-left)
			                         "THERE ARE 7 ROWS"
			                         "red green in row 2???"
			                         "row 3"
			                         `(:span
				                            (:fg :red "red")
			                            " "
			                            (:fg :green "green")
			                            " "
			                            "in row 4")
			                         (format nil "row 5~%row 6")
			                         "7: there's a border"))))

	    (shieldwall:shield "window center alignment 2"
                         "+------------+
| ARE 7 ROWS |
|reen in row |
|            |
|reen in row |
|            |
|            |
|ere's a bord|
+------------+
"
                         (skald:with-skald-test (:debug-mode :human-readable)
                           (skald:skald
			                       (skald:solo-window (4 4 :width 12
					                                           :height 7
					                                           :border t
					                                           :align :center-left)
			                         "THERE ARE 7 ROWS"
			                         "red green in row 2???"
			                         "row 3"
			                         `(:span
				                            (:fg :red "red")
			                            " "
			                            (:fg :green "green")
			                            " "
			                            "in row 4")
			                         (format nil "row 5~%row 6")
			                         "7: there's a border"))))
      
	    )


      (shieldwall:with-shield-group "WINDOW foreground/background and border"


      ;;;; clickaround tests
      #+nil
      (bifrost:with-bifrost
        (skald:skald-init)
        (skald:skald ()
	        (skald:solo-window (3 3
			                          :width 6
			                          :height 5
			                          :fg :yellow
			                          :bg :cyan
			                          :border t
			                          :border-fg :red
			                          :border-bg :blue)
	          (format nil "~%one~%two~%three~%"))))


      ;;;; unit test
        (shieldwall:shield "window colors 1"
                           "\\x1B[44m\\x1B[31m\\x1B[4;4H+------+\\x1B[5;4H|\\x1B[46m\\x1B[33m      \\x1B[44m\\x1B[31m|\\x1B[6;4H|\\x1B[46m\\x1B[33mone   \\x1B[44m\\x1B[31m|\\x1B[7;4H|\\x1B[46m\\x1B[33mtwo   \\x1B[44m\\x1B[31m|\\x1B[8;4H|\\x1B[46m\\x1B[33mthree \\x1B[44m\\x1B[31m|\\x1B[9;4H|\\x1B[46m\\x1B[33m      \\x1B[44m\\x1B[31m|\\x1B[10;4H+------+\\x1B[37m\\x1B[40m"
                         (skald:with-skald-test ()
                           (skald:skald
		                         (skald:solo-window (4 4
				                                           :width 6
				                                           :height 5
				                                           :fg :yellow
				                                           :bg :cyan
				                                           :border t
				                                           :border-fg :red
				                                           :border-bg :blue)
			                         (format nil "~%one~%two~%three~%")))))
        )

      #+nil
      (shieldwall:shield "SOLO-WINDOW leaves behind \"extent\" variables (no border)"
                         '(2 4 7 9)
                         (progn
                           (skald:with-skald-test ()
                             (skald:skald
		                           (skald:solo-window (2 4
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
                           (list skald:*extant-min-row*
                                 skald:*extant-min-col*
                                 skald:*extant-max-row*
                                 skald:*extant-max-col*)))
      #+nil
      (shieldwall:shield "SOLO-WINDOW leaves behind \"extent\" variables (with border)"
                         '(2 4 9 11)
                         (progn
                           (skald:with-skald-test ()
                             (skald:skald
		                           (skald:solo-window (2 4
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
                           (list skald:*extant-min-row*
                                 skald:*extant-min-col*
                                 skald:*extant-max-row*
                                 skald:*extant-max-col*)))
    )


    (shieldwall:with-shield-group "GRID/COLUMN/WINDOW"

    ;;;; clickaround tests
    #+nil
    (bifrost:with-bifrost
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
		                 (skald:window () "1")
 		                 (skald:window () "2")
		                 (skald:window () "3"))
		               (skald:column ()
		                 (skald:window () "4")
 		                 (skald:window () "5")
		                 (skald:window () "6"))
		               (skald:column ()
		                 (skald:window () "7")
 		                 (skald:window () "8")
		                 (skald:window () "9")))))
        (skald:skald-init)
        (skald:skald ()
	        (draw-background))
        (sleep 1)
        (skald:skald-overlay
	        (draw-table :border t
		                  :border-chars nil))
        (sleep 1)
        (skald:skald-overlay
	        (draw-table :border t
		                  :border-chars "-|+)"))
        (sleep 1)
        (skald:skald
	        (draw-background))
        (sleep 1)
        (skald:skald-overlay
	        (draw-table :border nil))))



      (shieldwall:with-shield-group "GRID/COLUMN/WINDOW tests"
    
        (shieldwall:with-shield-group "simple GRID/COLUMN/WINDOW"

          (shieldwall:shield "grid: 1x3"
                             "+----+
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
                             (skald:with-skald-test (:debug-mode :human-readable)
                               (skald:skald
		                             (skald:grid (3 3 :width 4
				                                          :height 3)
			                             (skald:column ()
			                               (skald:window () "1")
 			                               (skald:window () "2")
			                               (skald:window () "3"))))))

      
          (shieldwall:shield "grid: 3x1"
                             "+----+----+----+
|1   |2   |3   |
|    |    |    |
|    |    |    |
+----+----+----+
"
                             (skald:with-skald-test (:debug-mode :human-readable)
                               (skald:skald
		                             (skald:grid (3 3 :width 4 :height 3)
			                             (skald:column ()
			                               (skald:window () "1"))
			                             (skald:column ()
 			                               (skald:window () "2"))
			                             (skald:column ()
			                               (skald:window () "3"))))))

          (shieldwall:shield "grid: 3x3"
                             "+----+----+----+
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
                             (skald:with-skald-test (:debug-mode :human-readable)
                               (skald:skald
		                             (skald:grid (5 5 :width 4 :height 3)
			                             (skald:column ()
			                               (skald:window () "1")
 			                               (skald:window () "2")
			                               (skald:window () "3"))
			                             (skald:column ()
			                               (skald:window () "4")
 			                               (skald:window () "5")
			                               (skald:window () "6"))
			                             (skald:column ()
			                               (skald:window () "7")
 			                               (skald:window () "8")
			                               (skald:window () "9"))))))
        )

        (shieldwall:with-shield-group "GRID/COLUMN/WINDOW with transparant border (not the same as no border)"

          (shieldwall:shield "grid: 3x3 transparant border (not the same as no border)"
                             "1    4    7   
              
              
2    5    8   
              
              
3    6    9   
              
              
"
                             (skald:with-skald-test (:debug-mode :human-readable)
                               (skald:skald
		                             (skald:grid (5 5 :width 4
				                                          :height 3
				                                          :border t
				                                          :border-chars nil)
			                             (skald:column ()
			                               (skald:window () "1")
 			                               (skald:window () "2")
			                               (skald:window () "3"))
			                             (skald:column ()
			                               (skald:window () "4")
 			                               (skald:window () "5")
			                               (skald:window () "6"))
			                             (skald:column ()
			                               (skald:window () "7")
 			                               (skald:window () "8")
			                               (skald:window () "9"))))))
          )

        (shieldwall:with-shield-group "GRID/COLUMN/WINDOW without ASCII border"

          (shieldwall:shield "grid: 3x3 no border"
                             "1   4   7   
            
            
2   5   8   
            
            
3   6   9   
            
            
"
                             (skald:with-skald-test (:debug-mode :human-readable)
                               (skald:skald
		                             (skald:grid (5 5 :width 4
				                                          :height 3
				                                          :border nil)
			                             (skald:column ()
			                               (skald:window () "1")
 			                               (skald:window () "2")
			                               (skald:window () "3"))
			                             (skald:column ()
			                               (skald:window () "4")
 			                               (skald:window () "5")
			                               (skald:window () "6"))
			                             (skald:column ()
			                               (skald:window () "7")
 			                               (skald:window () "8")
			                               (skald:window () "9"))))))
          )
        )


      (shieldwall:with-shield-group ":NODISPLAY"

        (shieldwall:shield "span :NODISPLAY"
                           ""
                           (skald:with-skald-test ()
		                         (skald:skald
		                           (skald:span (3 4)
				                         :nodisplay))))

          
        (shieldwall:shield "span :NODISPLAY with args 1"
                           ""
                           (skald:with-skald-test ()
		                           (skald:skald
		                             (skald:span (3 4)
				                           '(:nodisplay "foo")))))

        (shieldwall:shield "span :NODISPLAY with args 2)"
                           "\\x1B[4;5Hfoobuz"
                             (skald:with-skald-test ()
		                           (skald:skald
		                             (skald:span (4 5)
			                             "foo"
			                             '(:nodisplay "bar" (:span "baz"))
			                             '(:span "buz" (:nodisplay "booze"))))))

        (shieldwall:shield "sprite :NODISPLAY"
                           ""
                           (skald:with-skald-test ()
		                         (skald:skald
		                           (skald:sprite (3 4)
				                         :nodisplay))))
          
        (shieldwall:shield "sprite :NODISPLAY with args 1"
                           ""
                           (skald:with-skald-test ()
		                         (skald:skald
		                           (skald:sprite (3 4)
				                         '(:nodisplay "foo")))))

        (shieldwall:shield ":NODISPLAY mixe"
                           "\\x1B[4;5Hfoobuz"
                           (skald:with-skald-test ()
		                         (skald:skald
		                           (skald:span (4 5)
			                           "foo"
			                           '(:nodisplay "bar" (:span "baz"))
			                           '(:span "buz" (:nodisplay "booze"))))))
      )

      (shieldwall:with-shield-group ":CALL-WITH-POINT"


        (shieldwall:shield ":CALL-WITH-POINT within a window :SPAN"
                           '("+----------+
|foo       |
|bar       |
|baz       |
|          |
|          |
|          |
|          |
|          |
|          |
|          |
+----------+
"
                             (5 . 6))
		                       (let (point)
                             (list (skald:with-skald-test (:debug-mode :human-readable)
                                     (skald:skald
			                                 (skald:solo-window (3 3
					                                                   :width 10
					                                                   :height 10)
			                                   "foo"
			                                   `(:span "ba"
                                            (:call-with-point ,(lambda (row col)
                                                                 (setf point (cons row col))
                                                                :no-display))
			                                      "r")
                                         "baz")))
		                               point)))
      
        (shieldwall:shield ":CALL-WITH-POINT in grid"
                           '((2 . 2) (2 . 4) (2 . 6) (9 . 2) (9 . 4) (9 . 6) (16 . 2) (16 . 4) (16 . 6))
		                     (let (accum)
		                       (flet ((fn (y x)
			                              (push (cons y x) accum)))
                             (skald:with-skald-test (:debug-mode :human-readable)
                               (skald:skald
			                           (skald:grid (1 1
					                                      :width 6
					                                      :height 1
					                                      :border t
					                                      :align :left)
			                             (skald:column ()
			                               (skald:window () `(:call-with-point ,#'fn))
			                               (skald:window () `(:call-with-point ,#'fn))
			                               (skald:window () `(:call-with-point ,#'fn)))
			                             (skald:column ()
			                               (skald:window () `(:call-with-point ,#'fn))
			                               (skald:window () `(:call-with-point ,#'fn))
			                               (skald:window () `(:call-with-point ,#'fn)))
			                             (skald:column ()
			                               (skald:window () `(:call-with-point ,#'fn))
			                               (skald:window () `(:call-with-point ,#'fn))
			                               (skald:window () `(:call-with-point ,#'fn))))))
		                         (nreverse accum))))
     
        )
    


      (shieldwall:with-shield-group "GRID/COLUMN/WINDOW :ALIGN"

        (shieldwall:shield "grid align (odd width content)"
                           "window=15 sprite=7
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
                           (skald:with-skald-test (:debug-mode :human-readable)
                             (skald:skald
		                           (skald:span (1 1) "window=15 sprite=7")
		                           (skald:grid (2 1 :width 13 :height 1)
			                           (skald:column ()
			                             (skald:window (:align :left)          "      |")
			                             (skald:window (:align :left)          "ODD_NU|")   
			                             (skald:window (:align :center-left)      "ODD|NUM")
			                             (skald:window (:align :center-right)     "ODD|NUM")
			                             (skald:window (:align :right)               "|DD_NUM") 
			                             (skald:window (:align :right)               "|      "))))))
                          
        (shieldwall:shield "grid align (odd width content, odd width window, squished)"
                           "window=7 sprite=7
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
                           (skald:with-skald-test (:debug-mode :human-readable)
                             (skald:skald
		                           (skald:span (1 1) "window=7 sprite=7")
		                           (skald:grid (2 1 :width 7 :height 1)
			                           (skald:column ()
			                             (skald:window (:align :left)          "   |   ")
			                             (skald:window (:align :left)          "ODD|NUM")   
			                             (skald:window (:align :center-left)      "ODD|NUM")
			                             (skald:window (:align :center-right)     "ODD|NUM")
			                             (skald:window (:align :right)               "ODD|NUM") 
			                             (skald:window (:align :right)               "   |   "))))))

        (shieldwall:shield "grid align (odd width content, odd width window, more squished)"
                           "window=5 sprite=7
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
                           (skald:with-skald-test (:debug-mode :human-readable)
                             (skald:skald
		                           (skald:span (1 1) "window=5 sprite=7")
		                           (skald:grid (2 1 :width 5 :height 1)
			                           (skald:column ()
			                             (skald:window (:align :left)          "  |    ")
			                             (skald:window (:align :left)          "OD|_NUM")   
			                             (skald:window (:align :center-left)      "ODD|NUM")
			                             (skald:window (:align :center-right)     "ODD|NUM")
			                             (skald:window (:align :right)               "ODD_|UM") 
			                             (skald:window (:align :right)               "    |  "))))))

    
        (shieldwall:shield "grid align (odd width content, even width window)"
                           "window=14 sprite=7
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
                           (skald:with-skald-test (:debug-mode :human-readable)
                             (skald:skald
		                           (skald:span (1 1) "window=14 sprite=7")
		                           (skald:grid (2 1 :width 14 :height 1)
			                           (skald:column ()
			                             (skald:window (:align :left)          "      |")
			                             (skald:window (:align :left)          "ODD_NU|")
			                             (skald:window (:align :center-left)      "ODD|NUM")
			                             (skald:window (:align :left)          "      \\")
			                             (skald:window (:align :center-right)     "ODD|NUM")
			                             (skald:window (:align :right)               "|DD_NUM") 
			                             (skald:window (:align :right)               "|      "))))))

        (shieldwall:shield "grid align (odd width content, even width window, squished)"
                           "window=4 sprite=7
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
                           (skald:with-skald-test (:debug-mode :human-readable)
                             (skald:skald
		                           (skald:span (1 1) "window=4 sprite=7")
		                           (skald:grid (2 1 :width 4 :height 1)
			                           (skald:column ()
			                             (skald:window (:align :left)            " |     ")
			                             (skald:window (:align :left)            "O|D_NUM")
			                             (skald:window (:align :center-left)   "ODD|NUM")
			                             (skald:window (:align :left)            " \\     ")
			                             (skald:window (:align :center-right)  "ODD|NUM")
			                             (skald:window (:align :right)       "ODD_N|M") 
			                             (skald:window (:align :right)        "    | "))))))
   
        (shieldwall:shield "grid align (even width content, even width window)"
         "window=16 sprite=8
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
                         (skald:with-skald-test (:debug-mode :human-readable)
                           (skald:skald
		                         (skald:span (1 1) "window=16 sprite=8")
		                         (skald:grid (2 1 :width 16 :height 1)
			                         (skald:column ()
			                           (skald:window (:align :left)         "       |")
			                           (skald:window (:align :left)         "EVEN_NU|")
			                           (skald:window (:align :center-left)     "EVE|_NUM")
			                           (skald:window (:align :left)         "       \\")
			                           (skald:window (:align :center-right)      "EVEN|NUM")
			                           (skald:window (:align :right)               "|VEN_NUM")
			                           (skald:window (:align :right)               "|       "))))))
      
        (shieldwall:shield "grid align (even width content, even width window, squished)"
                           "window=8 sprite=8
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
                           (skald:with-skald-test (:debug-mode :human-readable)
                             (skald:skald
		                           (skald:span (1 1) "window=8 sprite=8")
		                           (skald:grid (2 1 :width 8 :height 1)
			                           (skald:column ()
			                             (skald:window (:align :left)         "   |    ")
			                             (skald:window (:align :left)         "EVE|_NUM")
			                             (skald:window (:align :center-left)  "EVE|_NUM")
			                             (skald:window (:align :center-right) "EVE|_NUM")
			                             (skald:window (:align :right)        "EVE|_NUM")
			                             (skald:window (:align :right)        "   |    "))))))
      
        (shieldwall:shield "grid align (even width content, even width window, more squished)"
                           "window=4 sprite=8
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
                           (skald:with-skald-test (:debug-mode :human-readable)
                             (skald:skald
		                           (skald:span (1 1) "window=4 sprite=8")
		                           (skald:grid (2 1 :width 4 :height 1)
			                           (skald:column ()
			                             (skald:window (:align :left)              " |      ")
			                             (skald:window (:align :left)              "E|EN_NUM")
			                             (skald:window (:align :center-left)     "EVE|_NUM")
			                             (skald:window (:align :left)              " \\     ")
			                             (skald:window (:align :center-right)   "EVEN|NUM")
			                             (skald:window (:align :right)        "EVEN_N|M")
			                             (skald:window (:align :right)        "      | "))))))
		    
        (shieldwall:shield "grid align (even width content, odd width window"
                          "+-----------------+
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
                          (skald:with-skald-test (:debug-mode :human-readable)
                            (skald:skald
		                          (skald:grid (2 1 :width 17 :height 1)
			                          (skald:column ()
			                            (skald:window (:align :left)         "       |")
			                            (skald:window (:align :left)         "EVEN_NU|")
			                            (skald:window (:align :center-left)     "EVE|_NUM")
			                            (skald:window (:align :left)         "       \\")
			                            (skald:window (:align :right)        "\\       ")
			                            (skald:window (:align :center-right)      "EVEN|NUM")
			                            (skald:window (:align :right)               "|VEN_NUM")
			                            (skald:window (:align :right)               "|       "))))))
      
        (shieldwall:shield "grid align (even width content, odd width window, squished)"
                           "window=5 sprite=8
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
                           (skald:with-skald-test (:debug-mode :human-readable)
                             (skald:skald
		                           (skald:span (1 1) "window=5 sprite=8")
		                           (skald:grid (2 1 :width 5 :height 1)
			                           (skald:column ()
			                             (skald:window (:align :left)         "  |     ")
			                             (skald:window (:align :left)         "EV|N_NUM")
			                             (skald:window (:align :center-left)     "EVEN|NUM")
			                             (skald:window (:align :center-right)      "EVE|_NUM")
			                             (skald:window (:align :right)               "EVEN_|UM")
			                             (skald:window (:align :right)               "     |  "))))))
        )
    )

  
    (shieldwall:with-shield-group ":TRANSPARANT-CHAR"

    ;;;; clickaround tests
      #+nil
      (bifrost:with-bifrost
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
          (skald:skald
	          (draw-background))
          (sleep 1)
          (dolist (c '(#\x #\o))
	          (skald:skald
	            (draw-background)
	            (draw-foreground c))
	          (sleep 1))))
      
      #+nil
      (bifrost:with-bifrost
        (flet ((draw-background ()
	               (let* ((row (make-string 22 :initial-element #\.))
		                    (rectangle (loop repeat 16
				                                 collect row)))
	                 (skald:sprite (2 2)
		                 `(:sprite ,@rectangle))))
	             (draw-table (transparant-char)
	               (skald:solo-window (4 4
			                                 :width 16
			                                 :height 10
			                                 :fill-char #\~
			                                 :transparant-char transparant-char
			                                 :fg :cyan
			                                 :bg :blue
			                                 :border t
			                                 :border-fg :black
			                                 :border-bg :white
			                                 :align :center-left)
	                 (format nil "~%entertain~%three~%educated~%elephants~%"))))
          (skald:skald-init)
          (dolist (c '(#\nul #\e #\~))
	          (skald:skald
	            (draw-background))
	          (sleep 1)
	          (skald:skald-overlay
	            (draw-table c))
	          (sleep 2))))
	    
    ;;;; unit tests
      (shieldwall:shield "WINDOW :TRANSPARANT-CHAR 1"
                         "\\x1B[44m\\x1B[31m\\x1B[5;5H+----------------+\\x1B[6;5H|\\x1B[46m\\x1B[33m~~~~~~~~~~~~~~~~\\x1B[44m\\x1B[31m|\\x1B[7;5H|\\x1B[46m\\x1B[33m~~~~\\x1B[7;11Hnt\\x1B[7;14Hrtain~~~\\x1B[44m\\x1B[31m|\\x1B[8;5H|\\x1B[46m\\x1B[33m~~~~thr\\x1B[8;15H~~~~~~~\\x1B[44m\\x1B[31m|\\x1B[9;5H|\\x1B[46m\\x1B[33m~~~~\\x1B[9;11Hducat\\x1B[9;17Hd~~~~\\x1B[44m\\x1B[31m|\\x1B[10;5H|\\x1B[46m\\x1B[33m~~~~\\x1B[10;11Hl\\x1B[10;13Hphants~~~\\x1B[44m\\x1B[31m|\\x1B[11;5H|\\x1B[46m\\x1B[33m~~~~~~~~~~~~~~~~\\x1B[44m\\x1B[31m|\\x1B[12;5H|\\x1B[46m\\x1B[33m~~~~~~~~~~~~~~~~\\x1B[44m\\x1B[31m|\\x1B[13;5H|\\x1B[46m\\x1B[33m~~~~~~~~~~~~~~~~\\x1B[44m\\x1B[31m|\\x1B[14;5H|\\x1B[46m\\x1B[33m~~~~~~~~~~~~~~~~\\x1B[44m\\x1B[31m|\\x1B[15;5H|\\x1B[46m\\x1B[33m~~~~~~~~~~~~~~~~\\x1B[44m\\x1B[31m|\\x1B[16;5H+----------------+\\x1B[37m\\x1B[40m"
		                     (let ((transparant-char #\e))
                           (skald:with-skald-test ()
                             (skald:skald
		                           (skald:solo-window (5 5
				                                             :width 16
				                                             :height 10
				                                             :fill-char #\~
				                                             :transparant-char transparant-char
				                                             :fg :yellow
				                                             :bg :cyan
				                                             :border t
				                                             :border-fg :red
				                                             :border-bg :blue
				                                             :align :center-left)
			                           (format nil "~%entertain~%three~%educated~%elephants~%"))))))
      
      (shieldwall:shield "WINDOW :TRANSPARANT-CHAR 2"
                         "\\x1B[44m\\x1B[31m\\x1B[5;5H+----------------+\\x1B[6;5H|\\x1B[6;22H|\\x1B[7;5H|\\x1B[46m\\x1B[33m\\x1B[7;9Hentertain\\x1B[44m\\x1B[31m\\x1B[7;22H|\\x1B[8;5H|\\x1B[46m\\x1B[33m\\x1B[8;9Hthree\\x1B[44m\\x1B[31m\\x1B[8;22H|\\x1B[9;5H|\\x1B[46m\\x1B[33m\\x1B[9;9Heducated\\x1B[44m\\x1B[31m\\x1B[9;22H|\\x1B[10;5H|\\x1B[46m\\x1B[33m\\x1B[10;9Helephants\\x1B[44m\\x1B[31m\\x1B[10;22H|\\x1B[11;5H|\\x1B[11;22H|\\x1B[12;5H|\\x1B[12;22H|\\x1B[13;5H|\\x1B[13;22H|\\x1B[14;5H|\\x1B[14;22H|\\x1B[15;5H|\\x1B[15;22H|\\x1B[16;5H+----------------+\\x1B[37m\\x1B[40m"
		                     (let ((transparant-char #\~))
                           (skald:with-skald-test ()
                             (skald:skald
		                           (skald:solo-window (5 5
				                                             :width 16
				                                             :height 10
				                                             :fill-char #\~
				                                             :transparant-char transparant-char
				                                             :fg :yellow
				                                             :bg :cyan
				                                             :border t
				                                             :border-fg :red
				                                             :border-bg :blue
				                                             :align :center-left)
			                           (format nil "~%entertain~%three~%educated~%elephants~%"))))))
      )




    (shieldwall:with-shield-group "EMOJI EDGE CASES"

  ;;; Notation reminder:
  ;;;   A+z = double-width character A followed by #\ZERO_WIDTH_SPACE
  ;;;   { } = bounding box boundaries
  ;;;   ?   = #\REPLACEMENT_CHARACTER (renders as *unrenderable-char-fill-char*)
  ;;;   X+z = the double-width character we're trying to INSERT

  
  (shieldwall:with-shield-group "double-width char at buffer start, single-width insert"
    
    ;; This should chop the emoji, leaving artifact at position 1
    (shieldwall:shield "A+z c d > ? x c d"
                       `(,skald:*unrenderable-char-fill-char* #\x #\c #\d #\newline)
                       (coerce (progn
                                 (skald:with-skald-test (:override-drawmode :prep)
                                   (skald:skald-init)
                                   (skald:skald
                                     (skald:span (1 1)
                                       #\grinning_face  ;; positions 1-2 (char + zwsp)
                                       #\c              ;; position 3
                                       #\d)))           ;; position 4
                                 (skald:with-skald-test (:debug-mode :human-readable)
                                   (skald:skald
                                     ;; No bounding box, just raw write at position 2
                                     (skald::with-window-bounding-box nil nil nil nil
                                       (setf skald:*row* 1
                                             skald:*col* 2)
                                       (skald::%render-span #\x)))))
                               'list))
    
    ;; This shouldn't affect the emoji at positions 3-4
    (shieldwall:shield "a b C+z > a x C+z"
                       '(#\a #\x #\grinning_face #\newline)
                       (coerce (progn
                                 (skald:with-skald-test (:override-drawmode :prep)
                                   (skald:skald-init)
                                   (skald:skald
                                     (skald:span (1 1)
                                       #\a              ;; position 1
                                       #\b              ;; position 2  
                                       #\grinning_face))) ;; positions 3-4
                                 (skald:with-skald-test (:debug-mode :human-readable)
                                   (skald:skald
                                     (skald::with-window-bounding-box nil nil nil nil
                                       (setf skald:*row* 1
                                             skald:*col* 2)
                                       (skald::%render-span #\x)))))
                               'list))
  )

  (shieldwall:with-shield-group "double-width char at buffer start, double-width insert"
    
    ;; Old emoji gets chopped (position 1 becomes artifact), new emoji at 2-3
    (shieldwall:shield "A+z c d > ? X+z d"
                       `(,skald:*unrenderable-char-fill-char* 
                         #\neutral_face 
                         #\d 
                         #\newline)
                       (coerce (progn
                                 (skald:with-skald-test (:override-drawmode :prep)
                                   (skald:skald-init)
                                   (skald:skald
                                     (skald:span (1 1)
                                       #\grinning_face  ;; positions 1-2
                                       #\c              ;; position 3
                                       #\d)))           ;; position 4
                                 (skald:with-skald-test (:debug-mode :human-readable)
                                   (skald:skald
                                     (skald::with-window-bounding-box nil nil nil nil
                                       (setf skald:*row* 1
                                             skald:*col* 2)
                                       (skald::%render-span #\neutral_face)))))
                               'list))
    
    ;; New emoji occupies 2-3, which chops the old emoji's first cell
    (shieldwall:shield "a b C+z > a X+z ?"
                       `(#\a 
                         #\neutral_face 
                         ,skald:*unrenderable-char-fill-char*
                         #\newline)
                       (coerce (progn
                                 (skald:with-skald-test (:override-drawmode :prep)
                                   (skald:skald-init)
                                   (skald:skald
                                     (skald:span (1 1)
                                       #\a              ;; position 1
                                       #\b              ;; position 2
                                       #\grinning_face))) ;; positions 3-4
                                 (skald:with-skald-test (:debug-mode :human-readable)
                                   (skald:skald
                                     (skald::with-window-bounding-box nil nil nil nil
                                       (setf skald:*row* 1
                                             skald:*col* 2)
                                       (skald::%render-span #\neutral_face)))))
                               'list))
  )

  (shieldwall:with-shield-group "emoji before bounding box - no op cases"

    (shieldwall:shield "A++z {c d} single-width insert > no op"
                       '(#\grinning_face #\c #\d #\newline)
                       (coerce (progn
                                 (skald:with-skald-test (:override-drawmode :prep)
                                   (skald:skald-init)
                                   (skald:skald
                                     (skald:span (1 1)
                                       #\grinning_face  ;; positions 1-2
                                       #\c              ;; position 3
                                       #\d)))           ;; position 4
                                 (skald:with-skald-test (:debug-mode :human-readable)
                                   (skald:skald
                                     ;; Bounding box: row 1, height 3, column 3, width 2 (cols 3-4)
                                     (skald::with-window-bounding-box 1 3 3 2
                                       (setf skald:*row* 1
                                             skald:*col* 2)
                                       (skald::%render-span #\x)))))
                               'list))
    
    (shieldwall:shield "A++z {c d} double-width insert > no op"
                       '(#\grinning_face #\c #\d #\newline)
                       (coerce (progn
                                 (skald:with-skald-test (:override-drawmode :prep)
                                   (skald:skald-init)
                                   (skald:skald
                                     (skald:span (1 1)
                                       #\grinning_face
                                       #\c
                                       #\d)))
                                 (skald:with-skald-test (:debug-mode :human-readable)
                                   (skald:skald
                                     (skald::with-window-bounding-box 1 3 3 2
                                       (setf skald:*row* 1
                                             skald:*col* 2)
                                       (skald::%render-span #\neutral_face)))))
                               'list))
  )

      (shieldwall:with-shield-group "emoji at terminal edge"
    
        (shieldwall:shield "emoji at right edge of terminal becomes artifact"
                           `(#\a #\b ,skald:*unrenderable-char-fill-char* #\newline)
                           (coerce (skald:with-skald-test (:debug-mode :human-readable
                                                           :override-terminal-size '(3 4))
                                     ;; Terminal is 3 rows x 4 cols (indices 0-3, usable 1-3)
                                     (skald:skald-init)
                                     (skald:skald
                                       (skald:span (1 1)
                                         #\a    ;; position 1
                                         #\b    ;; position 2
                                         #\grinning_face)))  ;; position 3, but needs 3-4, col 4 is out
                                   'list))
  )

  
  (shieldwall:with-shield-group "consecutive emojis"

    (shieldwall:shield "two consecutive emojis render correctly"
                       '(#\grinning_face #\neutral_face #\newline)
                       (coerce (skald:with-skald-test (:debug-mode :human-readable)
                                 (skald:skald-init)
                                 (skald:skald
                                   (skald:span (1 1)
                                     #\grinning_face
                                     #\neutral_face)))
                               'list))
    
    ;; Overwriting first of two consecutive emojis with single char
    (shieldwall:shield "overwrite first of two consecutive emojis"
                       `(#\x ,skald:*unrenderable-char-fill-char*
                         #\neutral_face #\newline)
                       (coerce (progn
                                 (skald:with-skald-test (:override-drawmode :prep)
                                   (skald:skald-init)
                                   (skald:skald
                                     (skald:span (1 1)
                                       #\grinning_face    ;; 1-2
                                       #\neutral_face)))  ;; 3-4
                                 (skald:with-skald-test (:debug-mode :human-readable)
                                   (skald:skald
                                     (skald::with-window-bounding-box nil nil nil nil
                                       (setf skald:*row* 1
                                             skald:*col* 1)
                                       (skald::%render-span #\x)))))
                               'list))
    
    ;; Overwriting at the boundary between two emojis (position 2 = zwsp of first)
    (shieldwall:shield "overwrite boundary between consecutive emojis"
                       `(,skald:*unrenderable-char-fill-char*  ;; first emoji chopped
                         #\x                                   ;; our insert
                         #\neutral_face  ;; second emoji chopped (was at 3)
                         #\newline)
                       (coerce (progn
                                 (skald:with-skald-test (:override-drawmode :prep)
                                   (skald:skald-init)
                                   (skald:skald
                                     (skald:span (1 1)
                                       #\grinning_face    ;; 1-2 (char, zwsp)
                                       #\neutral_face)))  ;; 3-4 (char, zwsp)
                                 (skald:with-skald-test (:debug-mode :human-readable)
                                   (skald:skald
                                     (skald::with-window-bounding-box nil nil nil nil
                                       (setf skald:*row* 1
                                             skald:*col* 2)
                                       (skald::%render-span #\x)))))
                               'list))
  )
  
  (shieldwall:with-shield-group "emojis in windows with alignment"
    
    (shieldwall:shield "emoji in left-aligned window"
                       "+------+
|😀    |
|text  |
|      |
+------+
"
                       (skald:with-skald-test (:debug-mode :human-readable)
                         (skald:skald
                           (skald:solo-window (1 1 :width 6 :height 3 :align :left)
                             '(:emoji :grinning)
                             "text"))))
    
    (shieldwall:shield "emoji in right-aligned window"
                       "+------+
|  😀  |
|  text|
|      |
+------+
"
                       (skald:with-skald-test (:debug-mode :human-readable)
                         (skald:skald
                           (skald:solo-window (1 1 :width 6 :height 3 :align :right)
                             '(:emoji :grinning)
                             "text"))))
    
    ;; Emoji that gets clipped by narrow window
    (shieldwall:shield "emoji clipped by narrow window becomes artifact"
                       `(#\+ #\- #\+ #\newline
                         #\| ,skald:*unrenderable-char-fill-char* #\| #\newline
                         #\+ #\- #\+ #\newline)
                       (coerce (skald:with-skald-test (:debug-mode :human-readable)
                                 (skald:skald
                                   (skald:solo-window (1 1 :width 1 :height 1)
                                     #\grinning_face)))  ;; needs 2 cols, only 1 available
                               'list))
  )
)





    
  (shieldwall:with-shield-group "FIXED-STEP-LINE"

    (shieldwall:shield "fixed-step-line"
                       '((1 . 1) (1 . 2) (2 . 4) (3 . 6) (4 . 8) (5 . 10))
		                   (skald:fixed-step-line :start-row 1
					                                    :start-column 1
					                                    :steps-inclusive 5
					                                    :end-row 5
					                                    :end-column 10))
    )
				




    
    (shieldwall:with-shield-group ":MASK"

    ;;;; clickaround tests
    #+ nil
    (bifrost:with-bifrost
      (flet ((draw (xx &optional mask)
	             (skald:span (3 10 :mask mask
			                           :align :center-left)
	               xx)))
        (skald:skald-init)
        (skald:skald () (draw "FOOBARBAZ"))
        (sleep 1)
        (skald:skald-overlay (draw "FOOBARBAZ" t))
        (sleep 1)
        (skald:skald-overlay (draw "foo"))
        (sleep 1)
        (skald:skald-overlay (draw "foo" t))
        (sleep 1)))

    #+ nil
    (bifrost:with-bifrost
      (flet ((draw (xx &optional mask)
	             (skald:span (3 10 :mask mask
			                           :align :center-left)
	               xx)))
        (skald:skald-init)
        (skald:skald (draw "FOOBARBAZ"))
        (sleep 1)
        (let ((skald:*override-skald-drawmode* :prep))
          (declare (special skald:*override-skald-drawmode*))
          (skald:skald (draw "FOOBARBAZ" t)))
        (sleep 1)
        (skald:skald-overlay (draw "foo"))
        (sleep 1)))
    
    #+ nil
    (bifrost:with-bifrost
      (let ((xx '(:span
		              "FOO"
		              (:fg :blue "BLUE")
		              #\&
		              (:bg :white
		                (:fg :red
		                  "RED"))
		              "BAR")))
        (skald:skald-init)
        (skald:skald
	        (skald:span (3 15 :align :center-left
			                      :fg :white
			                      :bg :black)
	          xx))
        (sleep 1)
        (skald:skald
	        (skald:span (3 15 :mask t
		                        :fill-char #\x
			                      :align :center-left
			                      :fg :cyan
			                      :bg :black)
	          xx))
        (sleep 1)))



    
    ;; unit tests
      (shieldwall:shield ":MASK"
                         "xxx
"
                         (skald:with-skald-test (:debug-mode :human-readable)
                           (skald:skald
			                       (skald:span (1 1 :mask t :fill-char #\x)
			                         "foo"))))
      )
    )
)
