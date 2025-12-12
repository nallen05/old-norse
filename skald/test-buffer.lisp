





(defpackage :skald-test
  (:use :cl :skald))


(in-package :skald-test)

;; (setf shieldwall::*shieldwall-suppress-errors-p* nil)

(shieldwall:with-shield-group "SKALD-DRAW, SPAN, & SPRITE"
  
  (shieldwall:with-shield-group "SKALD-DRAW tests"
    
    ;;;; clickaround tests
    ;; run this to verify that it wrote to the screen & background color looks ok
    #+nil
    (skald:with-skald-test (:override-terminal-size '(24 80))
      (skald:skald-clear)
      (skald:skald-draw (:force-overlay)
	      (skald:span (1 1) "foo")
	      (skald:span (3 6) "bar")
	      (skald:span (6 12) "baz"))
      (sleep 1)
      (skald:skald-draw (:force-overlay)
	      (skald:span (2 1) "FOO")
	      (skald:span (4 6) "BAR")
	      (skald:span (7 12) "BAZ"))
      )
    
    #+nil
    (skald:with-skald-test (:override-terminal-size '(24 80))
      (skald:skald-clear)
	    (skald:skald-draw (:force-overlay)
	      (skald:span (1 1)
	        `(:bg :green
	           "GREEN_SPAN")))
	    (sleep 1)
	    (skald:skald-draw (:force-overlay)
	      (skald:span (2 12)
	        `(:bg :blue
	           "BLUE_SPAN")))
	    (sleep 1)
	    (skald:skald-draw (:force-overlay)
	      (skald:span (6 10)
	        `(:bg :red
	           "RED_SPAN"))))

    (shieldwall:with-shield-group ":FORCE-OVERLAY"
      (shieldwall:shield ":FORCE-OVERLAY in :MACHINE-READABLE mode"
                         "\\x1B[2;2Htest1 aaa"
		                     (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :machine-readable
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
			                       (skald:span (2 2) "test1 aaa"))))

      (shieldwall:shield ":FORCE-OVERLAY in :HUMAN-READABLE mode"
                         "test1 aaa
"
		                     (skald:with-skald-test (:override-terminal-size '(24 80)
                                                   :debug-mode :human-readable
                                                 :output nil)
                           (skald:skald-draw (:force-overlay)
			                       (skald:span (2 2) "test1 aaa"))))

      
      
      (shieldwall:shield "slightly more complex :FORCE-OVERLAY in :MACHINE-READABLE mode"
                         '("\\x1B[2;2Htest2 aaa"
                           "\\x1B[2;2Htest2 bbb"
                           "\\x1B[2;2Htest2 ccc")
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :machine-readable)
                           
		                       (list
                            (skald:with-skald-test (:output nil)
                              (skald:skald-draw (:force-overlay)
		                            (skald:span (2 2) "test2 aaa")))
                            (skald:with-skald-test (:output nil)
                              (skald:skald-draw (:force-overlay)
		                            (skald:span (2 2) "test2 bbb")))
                            (skald:with-skald-test (:output nil)
                              (skald:skald-draw (:force-overlay)
		                            (skald:span (2 2) "test2 ccc"))))))

      (shieldwall:shield "slightly more complex :FORCE-OVERLAY in :HUMAN-READABLE mode"
                         '(
                           "test2 aaa
"
                           "test2 bbb
"
                           "test2 ccc
")

                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :human-readable)
                           
		                       (list
                            (skald:with-skald-test (:output nil)
                              (skald:skald-draw (:force-overlay)
		                            (skald:span (2 2) "test2 aaa")))
                            (skald:with-skald-test (:output nil)
                              (skald:skald-draw (:force-overlay)
		                            (skald:span (2 2) "test2 bbb")))
                            (skald:with-skald-test (:output nil)
                              (skald:skald-draw (:force-overlay)
		                            (skald:span (2 2) "test2 ccc"))))))


    (shieldwall:with-shield-group ":FORCE-OVERLAY SKALD-INIT"
      (shieldwall:shield "SKALD-INIT in :MACHINE-READABLE mode"
                         "\\x1B[0m\\x1B[40m\\x1B[37m\\x1B[2J\\x1B[?25l\\x1B[3;3Htest2 aaa"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :machine-readable
                                                 :output nil)
                           (skald:skald-init)
		                       (skald:skald-draw (:force-overlay)
		                         (skald:span (3 3) "test2 aaa"))))))

      
    (shieldwall:with-shield-group ":OVERLAY"
      (shieldwall:shield ":OVERLAY in :MACHINE-READABLE mode"
                         "\\x1B[0m\\x1B[40m\\x1B[37m\\x1B[2J\\x1B[?25l\\x1B[3;3Htest2 aaa"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :machine-readable
                                                 :output nil)
                           (skald:skald-init)
		                       (skald:skald-draw (:overlay)
		                         (skald:span (3 3) "test2 aaa"))))

      (shieldwall:shield "slightly more complex :OVERLAY in :MACHINE-READABLE mode"
                         '("\\x1B[0m\\x1B[40m\\x1B[37m\\x1B[2J\\x1B[?25l"
                           "\\x1B[3;3Htest2 aaa"
                           ""
                           "\\x1B[3;9Hbbb")
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :machine-readable)
                           (list (skald:with-skald-test (:output nil)
                                   (skald:skald-init))
                                 (skald:with-skald-test (:output nil)
                                   (skald:skald-draw (:overlay)
		                                 (skald:span (3 3) "test2 aaa")))
                                 (skald:with-skald-test (:output nil)
                                   (skald:skald-draw (:overlay)
		                                 (skald:span (3 3) "test2 aaa")))
                                 (skald:with-skald-test (:output nil)
                                   (skald:skald-draw (:overlay)
		                                 (skald:span (3 3) "test2 bbb"))))))
      
      (shieldwall:shield ":OVERLAY in :HUMAN-READABLE mode"
                         '(
                           ""
                           "test2 aaa
"
                           "
"
                           "bbb
")
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :human-readable)
                           (list (skald:with-skald-test (:output nil)
                                   (skald:skald-init))
                                 (skald:with-skald-test (:output nil)
                                   (skald:skald-draw (:overlay)
		                                 (skald:span (3 3) "test2 aaa")))
                                 (skald:with-skald-test (:output nil)
                                   (skald:skald-draw (:overlay)
		                                 (skald:span (3 3) "test2 aaa")))                               
                                 (skald:with-skald-test (:output nil)
                                   (skald:skald-draw (:overlay)
		                                 (skald:span (3 3) "test2 bbb"))))))
      )
    #+nil
    (skald:with-skald-test (:override-terminal-size '(24 80))
      (skald:skald-clear)
      (skald:skald-draw ()
	      (skald:span (1 1) "foo")
	      (skald:span (3 6) "bar")
	      (skald:span (6 12) "baz"))
      (sleep 1)
      (skald:skald-draw ()
	      (skald:span (2 1) "FOO")
	      (skald:span (4 6) "BAR")
	      (skald:span (7 12) "BAZ"))
      )

    #+nil
    (skald:with-skald-test (:override-terminal-size '(24 80))
      (skald:skald-clear)
	    (skald:skald-draw ()
	      (skald:span (1 1)
	        `(:bg :green
	           "GREEN_SPAN")))
	    (sleep 1)
	    (skald:skald-draw ()
	      (skald:span (2 12)
	        `(:bg :blue
	           "BLUE_SPAN")))
	    (sleep 1)
	    (skald:skald-draw ()
	      (skald:span (6 10)
	        `(:bg :red
	           "RED_SPAN"))))

    (shieldwall:with-shield-group ":DRAW"
      (shieldwall:shield ":DRAW in :MACHINE-READABLE mode"
                         '("\\x1B[0m\\x1B[40m\\x1B[37m\\x1B[2J\\x1B[?25l"
                           "\\x1B[2;2Htest 4 aaa"
                           "\\x1B[2;9Hbbb"
                           "\\x1B[2;2H    \\x1B[2;7H \\x1B[2;9H   \\x1B[3;3Htest 4 ccc")
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :machine-readable)
		                       (list (skald:with-skald-test (:output nil)
                                   (skald:skald-init))
                                 (skald:with-skald-test (:output nil)
                                   (skald:skald-draw ()
                                     (skald:span (2 2)
                                       "test 4 aaa")))
                                 (skald:with-skald-test (:output nil)
                                   (skald:skald-draw ()
                                     (skald:span (2 2)
                                       "test 4 bbb")))
                                 (skald:with-skald-test (:output nil)
                                   (skald:skald-draw ()
                                     (skald:span (3 3)
                                       "test 4 ccc"))))))
  
      (shieldwall:shield ":DRAW in :HUMAN-READABLE mode"
                         '(
                           ""
                           "test 4 aaa
"
                           "bbb
"
                           "          
test 4 ccc
")
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :human-readable)
		                       (list (skald:with-skald-test (:output nil)
                                   (skald:skald-init))
                                 (skald:with-skald-test (:output nil)
                                   (skald:skald-draw ()
                                     (skald:span (2 2)
                                       "test 4 aaa")))
                                 (skald:with-skald-test (:output nil)
                                   (skald:skald-draw ()
                                     (skald:span (2 2)
                                       "test 4 bbb")))
                                 (skald:with-skald-test (:output nil)
                                   (skald:skald-draw ()
                                     (skald:span (3 3)
                                       "test 4 ccc"))))))
      )

    (shieldwall:with-shield-group "WRITE-TO-CHANGE-BUFFER tests"
      ;; read the WRITE-TO-CHANGE-BUFFER source code to understand these tests better

      (shieldwall:with-shield-group "respect bounding boxes"

        (shieldwall:shield ("boring single width char insert" :test #'equal)
                           '(#\a #\x #\c #\d #\newline)                       
                           (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                     (skald:with-skald-test (:output nil)
                                       (skald:skald-init)
                                       (skald:skald-draw (:prep)
                                         (skald:span (1 1)
                                           "abcd")))
                                     (skald:with-skald-test (:output nil
                                                             :debug-mode :human-readable)
                                       (skald:skald-draw ()
                                         (skald:span (1 2)
                                           #\x))))
                                   'list))

        (shieldwall:shield "don't write outside the bounds of the buffer"
                           '(#\b #\Newline #\c #\newline)
                           (coerce (skald:with-skald-test (:override-terminal-size '(24 80)
                                                           :output nil
                                                           :debug-mode :human-readable)
                                     (skald:skald-init)
                                     (skald:skald-draw ()
                                       (skald:span (1 0)  #\a)
                                       (skald:span (2 1)  #\b)
                                       (skald:span (3 79) #\c)
                                       (skald:span (4 80) #\d)))
                                   'list))
        
        (shieldwall:shield "don't write outside the bounds of a window bounding box"
                           '((#\Newline)
                             (#\b #\c #\d #\Newline)
                             (#\a #\b #\c #\d #\Newline)
                             (#\a #\b #\Newline)
                             (#\a #\b #\c #\d #\Newline)
                             (#\a #\b #\Newline)
                             (#\Newline)
                             (#\Newline))
                           (mapcar (lambda (point)
                                     (destructuring-bind (row col)
                                         point
                                       (coerce (skald:with-skald-test (:override-terminal-size '(24 80)
                                                                       :output nil
                                                                       :debug-mode :human-readable)
                                                 (skald:skald-init)
                                                 (skald:skald-draw ()
                                                   (skald::with-window-bounding-box 2 5 2 5
                                                     (setf skald:*row* row
                                                           skald:*col* col)
                                                     (skald::%render-span "abcd"))))
                                               'list)))
                                   '((1 1)
                                     (2 1)
                                     (2 2)
                                     (2 5)
                                     (6 2)
                                     (6 5)
                                     (7 2)
                                     (7 7))))
        )

      (shieldwall:with-shield-group "double width chars / emoji"
        (assert (eql (code-char #x1F600) #\grinning_face))
        (assert (eql (code-char #x1F610) #\neutral_face))

      
        (shieldwall:shield "boring double width char insert"
                           '(#\a #\grinning_face #\zero_width_space #\d #\newline)
                           (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                     (skald:with-skald-test (:output nil)
                                       (skald:skald-init)
                                       (skald:skald-draw (:prep)
                                         (skald:span (1 1)
                                           "abcd")))
                                     (skald:with-skald-test (:output nil
                                                             :debug-mode :human-readable)
                                       (skald:skald-draw ()
                                         (skald:span (1 2)
                                           #\grinning_face))))
                                   'list))

        (shieldwall:with-shield-group "inserting a single width char on top of a double width char"
          (shieldwall:shield "double width split test 1"
                             `(,*unrenderable-char-fill-char* #\x #\c #\d #\newline)
                             (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                       (skald:with-skald-test (:output nil)
                                         (skald:skald-init)
                                         (skald:skald-draw (:prep)
                                           (skald:span (1 1)
                                             #\grinning_face
                                             "cd")))
                                       (skald:with-skald-test (:output nil
                                                               :debug-mode :human-readable)
                                         (skald:skald-draw ()
                                           (skald:span (1 2)
                                             #\x))))
                                     'list))
          
          (shieldwall:shield "double width split test 2"
                             `(#\a #\x ,*unrenderable-char-fill-char* #\d #\newline)
                             (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                       (skald:with-skald-test (:output nil)
                                         (skald:skald-init)
                                         (skald:skald-draw (:prep)
                                           (skald:span (1 1)
                                             #\a
                                             #\grinning_face
                                             #\d)))
                                       (skald:with-skald-test (:output nil
                                                               :debug-mode :human-readable)
                                         (skald:skald-draw ()
                                           (skald:span (1 2)
                                             #\x))))
                                     'list))

          (shieldwall:shield "double width split test 3"
                             '(#\a #\x #\grinning_face #\zero_width_space #\newline)
                             (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                       (skald:with-skald-test (:output nil)
                                         (skald:skald-init)
                                         (skald:skald-draw (:prep)
                                           (skald:span (1 1)
                                             "ab"
                                             #\grinning_face)))
                                       (skald:with-skald-test (:output nil
                                                               :debug-mode :human-readable)
                                         (skald:skald-draw ()
                                           (skald:span (1 2)
                                             #\x))))
                                     'list))
          )
        

        (shieldwall:with-shield-group "writing single width chars in conflict with both bounding box boundaries & double width char in buffer"

          ;; how to read the syntax of these comments:
          ;;  { }  = bounding box
          ;;  A+z = "double width character A". Z is the trailing extra cell.
          ;;  ?   = unrenderable character, created by A+z being split by bounding box or single width char
          
          (shieldwall:shield "A+{z  c  d} => ? x c d"
                             `(,*unrenderable-char-fill-char* #\x #\c #\d #\newline)
                             (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                       (skald:with-skald-test (:output nil)
                                         (skald:skald-init)
                                         (skald:skald-draw (:prep)
                                           (skald:span (1 1)
                                             #\grinning_face
                                             #\c
                                             #\d)))
                                       (skald:with-skald-test (:output nil
                                                               :debug-mode :human-readable)
                                         (skald:skald-draw ()
                                           (skald::with-window-bounding-box 1 3 2 3
                                             (setf skald:*row* 1
                                                   skald:*col* 2)
                                               (skald::%render-span #\x)))))
                                     'list))

          (shieldwall:shield "a {B++z  d}   =>   a x ? d"
                             `(#\a #\x ,*unrenderable-char-fill-char* #\d #\newline)
                             (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                       (skald:with-skald-test (:output nil)
                                         (skald:skald-init)
                                         (skald:skald-draw (:prep)
                                           (skald:span (1 1)
                                             #\a
                                             #\grinning_face
                                             #\d)))
                                       (skald:with-skald-test (:output nil
                                                               :debug-mode :human-readable)
                                         (skald:skald-draw ()
                                           (skald::with-window-bounding-box 1 3 2 3
                                             (setf skald:*row* 1
                                                   skald:*col* 2)
                                             (skald::%render-span #\x)))))
                                     'list))

          (shieldwall:shield "a  B+{z  d}  > no op"
                             '(#\a #\grinning_face #\zero_width_space #\d #\newline)
                             (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                       (skald:with-skald-test (:output nil)
                                         (skald:skald-init)
                                         (skald:skald-draw (:prep)
                                           (skald:span (1 1)
                                             #\a
                                             #\grinning_face
                                             #\d)))
                                       (skald:with-skald-test (:output nil
                                                               :debug-mode :human-readable)
                                         (skald:skald-draw ()
                                           (skald::with-window-bounding-box 1 3 3 2
                                             (setf skald:*row* 1
                                                   skald:*col* 2)
                                             (skald::%render-span #\x)))))
                                     'list))

          (shieldwall:shield "a  B++z {d}  -> no op"
                             '(#\a #\grinning_face #\zero_width_space #\d #\newline)
                             (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                       (skald:with-skald-test (:output nil)
                                         (skald:skald-init)
                                         (skald:skald-draw (:prep)
                                           (skald:span (1 1)
                                             #\a
                                             #\grinning_face
                                             #\d)))
                                       (skald:with-skald-test (:output nil
                                                               :debug-mode :human-readable)
                                         (skald:skald-draw ()
                                           (skald::with-window-bounding-box 1 3 4 1
                                             (setf skald:*row* 1
                                                   skald:*col* 2)
                                             (skald::%render-span #\x)))))
                                     'list))

          (shieldwall:shield "a {B++z} d    =>   a x ? d"
                             `(#\a #\x ,*unrenderable-char-fill-char* #\d #\newline)
                             (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                       (skald:with-skald-test (:output nil)
                                         (skald:skald-init)
                                         (skald:skald-draw (:prep)
                                           (skald:span (1 1)
                                             #\a
                                             #\grinning_face
                                             #\d)))
                                       (skald:with-skald-test (:output nil
                                                               :debug-mode :human-readable)
                                         (skald:skald-draw ()
                                           (skald::with-window-bounding-box 1 3 2 2
                                             (setf skald:*row* 1
                                                   skald:*col* 2)
                                             (skald::%render-span #\x)))))
                                     'list))
          
          (shieldwall:shield "{a  B}+z  d    >   a x ? d"
                             `(#\a #\x ,*unrenderable-char-fill-char* #\d #\newline)
                             (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                       (skald:with-skald-test (:output nil)
                                         (skald:skald-init)
                                         (skald:skald-draw (:prep)
                                           (skald:span (1 1)
                                             #\a
                                             #\grinning_face
                                             #\d)))
                                       (skald:with-skald-test (:output nil
                                                               :debug-mode :human-readable)
                                         (skald:skald-draw ()
                                           (skald::with-window-bounding-box 1 3 1 2
                                             (setf skald:*row* 1
                                                   skald:*col* 2)
                                             (skald::%render-span #\x)))))
                                     'list))
          
          (shieldwall:shield "{A++z} c  d    >   ? x c d"
                             `(,*unrenderable-char-fill-char* #\x #\c #\d #\newline)
                             (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                       (skald:with-skald-test (:output nil)
                                         (skald:skald-init)
                                         (skald:skald-draw (:prep)
                                           (skald:span (1 1)
                                             #\grinning_face
                                             #\c
                                             #\d)))
                                       (skald:with-skald-test (:output nil
                                                               :debug-mode :human-readable)
                                         (skald:skald-draw ()
                                           (skald::with-window-bounding-box 1 3 1 2
                                             (setf skald:*row* 1
                                                   skald:*col* 2)
                                             (skald::%render-span #\x)))))
                                     'list))
          )
        )

      (shieldwall:with-shield-group "writing double width chars in conflict with bounding box boundaries"
        (shieldwall:shield "simple box double width char insert test"
                           `((#\a #\grinning_face #\zero_width_space #\d #\newline)
                             (#\a #\grinning_face #\zero_width_space #\d #\newline)
                             (#\a #\b #\c #\d #\newline)
                             (#\a #\b #\c #\d #\newline)
                             (#\a #\grinning_face #\zero_width_space #\d #\newline)
                             (#\a ,*unrenderable-char-fill-char* #\c #\d #\newline))
                           (mapcar (lambda (%)
                                     (destructuring-bind (column width)
                                         %
                                       (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                                 (skald:with-skald-test (:output nil)
                                                   (skald:skald-init)
                                                   (skald:skald-draw (:prep)
                                                     (skald:span (1 1)
                                                       "abcd")))
                                                 (skald:with-skald-test (:output nil
                                                                         :debug-mode :human-readable)
                                                   (skald:skald-draw ()
                                                     (skald::with-window-bounding-box 1 2 column width
                                                       (setf skald:*row* 1
                                                             skald:*col* 2)
                                                       (skald::%render-span #\grinning_face)))))
                                               'list)))
                                   '((1 4)
                                     (2 3)
                                     (3 2)
                                     (4 1)
                                     (2 2)
                                     (1 2))))

      (shieldwall:with-shield-group "writing double width chars in conflict with both bounding box boundaries & double width char in buffer"

        (shieldwall:shield "A+{z  c  d}  =>   ? X+z d"
                           `(,*unrenderable-char-fill-char* #\grinning_face #\zero_width_space #\d #\newline)
                           (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                     (skald:with-skald-test (:output nil)
                                       (skald:skald-init)
                                       (skald:skald-draw (:prep)
                                         (skald:span (1 1)
                                           #\grinning_face
                                           #\c
                                           #\d)))
                                     (skald:with-skald-test (:output nil
                                                             :debug-mode :human-readable)
                                       (skald:skald-draw ()
                                         (skald::with-window-bounding-box 1 3 2 3
                                           (setf skald:*row* 1
                                                 skald:*col* 2)
                                           (skald::%render-span #\grinning_face)))))
                                   'list))
        
        (shieldwall:shield "a {B++z  d}   =>   a X+z d"
         '(#\a #\grinning_face #\zero_width_space #\d #\newline)
                           (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                     (skald:with-skald-test (:output nil)
                                       (skald:skald-init)
                                       (skald:skald-draw (:prep)
                                         (skald:span (1 1)
                                           #\a
                                           #\neutral_face
                                           #\d)))
                                     (skald:with-skald-test (:output nil
                                                             :debug-mode :human-readable)
                                       (skald:skald-draw ()
                                         (skald::with-window-bounding-box 1 3 2 3
                                           (setf skald:*row* 1
                                                 skald:*col* 2)
                                           (skald::%render-span #\grinning_face)))))
                                   'list))

        (shieldwall:shield "a B+{z  d}  => no op"
                           '(#\a #\neutral_face #\zero_width_space #\d #\newline)
                           (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                     (skald:with-skald-test (:output nil)
                                       (skald:skald-init)
                                       (skald:skald-draw (:prep)
                                         (skald:span (1 1)
                                           #\a
                                           #\neutral_face
                                           #\d)))
                                     (skald:with-skald-test (:output nil
                                                             :debug-mode :human-readable)
                                       (skald:skald-draw ()
                                         (skald::with-window-bounding-box 1 3 3 2
                                           (setf skald:*row* 1
                                                 skald:*col* 2)
                                           (skald::%render-span #\grinning_face)))))
                                   'list))


        (shieldwall:shield "a B++z {d}  > no op"
         '(#\a #\neutral_face #\zero_width_space #\d #\newline)
                           (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                     (skald:with-skald-test (:output nil)
                                       (skald:skald-init)
                                       (skald:skald-draw (:prep)
                                         (skald:span (1 1)
                                           #\a
                                           #\neutral_face
                                           #\d)))
                                     (skald:with-skald-test (:output nil
                                                             :debug-mode :human-readable)
                                       (skald:skald-draw ()
                                         (skald::with-window-bounding-box 1 3 4 1
                                           (setf skald:*row* 1
                                                 skald:*col* 2)
                                           (skald::%render-span #\grinning_face)))))
                                   'list))

        (shieldwall:shield "a {B++z} d  >    a X++z d"
                           '(#\a #\grinning_face #\zero_width_space #\d #\newline)
                           (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                     (skald:with-skald-test (:output nil)
                                       (skald:skald-init)
                                       (skald:skald-draw (:prep)
                                         (skald:span (1 1)
                                           #\a
                                           #\neutral_face
                                           #\d)))
                                     (skald:with-skald-test (:output nil
                                                             :debug-mode :human-readable)
                                       (skald:skald-draw ()
                                         (skald::with-window-bounding-box 1 3 2 2
                                           (setf skald:*row* 1
                                                 skald:*col* 2)
                                           (skald::%render-span #\grinning_face)))))
                                   'list))

        (shieldwall:shield "{a  b}+c  d    >   a ? ? d"
                           `(#\a
                             ,*unrenderable-char-fill-char*
                             ,*unrenderable-char-fill-char*
                             #\d
                             #\newline)
                           (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                     (skald:with-skald-test (:output nil)
                                       (skald:skald-init)
                                       (skald:skald-draw (:prep)
                                         (skald:span (1 1)
                                           #\a
                                           #\neutral_face
                                           #\d)))
                                     (skald:with-skald-test (:output nil
                                                             :debug-mode :human-readable)
                                       (skald:skald-draw ()
                                         (skald::with-window-bounding-box 1 3 1 2
                                           (setf skald:*row* 1
                                                 skald:*col* 2)
                                           (skald::%render-span #\grinning_face)))))
                                   'list))

        (shieldwall:shield "{a++b} c  d    >   ? x c d"
                           `(,*unrenderable-char-fill-char*
                             ,*unrenderable-char-fill-char*
                             #\c
                             #\d
                             #\newline)
                           (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                     (skald:with-skald-test (:output nil)
                                       (skald:skald-init)
                                       (skald:skald-draw (:prep)
                                         (skald:span (1 1)
                                           #\neutral_face
                                           #\c
                                           #\d)))
                                     (skald:with-skald-test (:output nil
                                                             :debug-mode :human-readable)
                                       (skald:skald-draw ()
                                         (skald::with-window-bounding-box 1 3 1 2
                                           (setf skald:*row* 1
                                                 skald:*col* 2)
                                           (skald::%render-span #\grinning_face)))))
                                   'list))
        )
        )
      )
    )
  )
