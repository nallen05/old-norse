





(defpackage :skald-test
  (:use :cl :skald))


(in-package :skald-test)

(setf swordbreaker::*muffle-test-errors-p* nil)

(swordbreaker:with-test-group "SKALD-DRAW, SPAN, & SPRITE"
  
  (swordbreaker:with-test-group "SKALD-DRAW tests"
    
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
	        `(:with-background :green
	           "GREEN_SPAN")))
	    (sleep 1)
	    (skald:skald-draw (:force-overlay)
	      (skald:span (2 12)
	        `(:with-background :blue
	           "BLUE_SPAN")))
	    (sleep 1)
	    (skald:skald-draw (:force-overlay)
	      (skald:span (6 10)
	        `(:with-background :red
	           "RED_SPAN"))))

    (swordbreaker:with-test-group "SKALD-DRAW :FORCE-OVERLAY"
        (swordbreaker:test "\\x1B[2;2Htest1 aaa"
		                       (skald:with-skald-test (:override-terminal-size '(24 80)
                                                   :debug-mode :escape-control
                                                   :output nil)
                             (skald:skald-draw (:force-overlay)
			                         (skald:span (2 2) "test1 aaa"))
                             )
		                       :test #'equal)

        (swordbreaker:test "test1 aaa
"
		                       (skald:with-skald-test (:override-terminal-size '(24 80)
                                                   :debug-mode :no-control
                                                   :output nil)
                             (skald:skald-draw (:force-overlay)
			                         (skald:span (2 2) "test1 aaa"))
                             )
		                       :test #'equal)

      
      
        (swordbreaker:test '("\\x1B[2;2Htest2 aaa"
                             "\\x1B[2;2Htest2 bbb"
                             "\\x1B[2;2Htest2 ccc")
                           (skald:with-skald-test (:override-terminal-size '(24 80)
                                                   :debug-mode :escape-control)
                             
		                         (list
                              (skald:with-skald-test (:output nil)
                                (skald:skald-draw (:force-overlay)
		                              (skald:span (2 2) "test2 aaa")))
                              (skald:with-skald-test (:output nil)
                                (skald:skald-draw (:force-overlay)
		                              (skald:span (2 2) "test2 bbb")))
                              (skald:with-skald-test (:output nil)
                                (skald:skald-draw (:force-overlay)
		                              (skald:span (2 2) "test2 ccc")))))
		                       :test #'equal)

        (swordbreaker:test  '(
                              "test2 aaa
"
                              "test2 bbb
"
                              "test2 ccc
")

                            (skald:with-skald-test (:override-terminal-size '(24 80)
                                                    :debug-mode :no-control)

		                          (list
                               (skald:with-skald-test (:output nil)
                                 (skald:skald-draw (:force-overlay)
		                               (skald:span (2 2) "test2 aaa")))
                               (skald:with-skald-test (:output nil)
                                 (skald:skald-draw (:force-overlay)
		                               (skald:span (2 2) "test2 bbb")))
                               (skald:with-skald-test (:output nil)
                                 (skald:skald-draw (:force-overlay)
		                               (skald:span (2 2) "test2 ccc")))))
		                        :test #'equalp)
      )


    (swordbreaker:with-test-group "SKALD-INIT"
      (swordbreaker:test "\\x1B[0m\\x1B[40m\\x1B[37m\\x1B[2J\\x1B[?25l\\x1B[3;3Htest2 aaa"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :escape-control
                                                 :output nil)
                           (skald:skald-init)
		                       (skald:skald-draw (:force-overlay)
		                         (skald:span (3 3) "test2 aaa")))
		                     :test #'equal)
      )


    (swordbreaker:with-test-group ":OVERLAY"
      (swordbreaker:test "\\x1B[0m\\x1B[40m\\x1B[37m\\x1B[2J\\x1B[?25l\\x1B[3;3Htest2 aaa"
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :escape-control
                                                 :output nil)
                           (skald:skald-init)
		                       (skald:skald-draw (:overlay)
		                         (skald:span (3 3) "test2 aaa")))
		                     :test #'equal)

      (swordbreaker:test '("\\x1B[0m\\x1B[40m\\x1B[37m\\x1B[2J\\x1B[?25l"
                           "\\x1B[3;3Htest2 aaa"
                           ""
                           "\\x1B[3;9Hbbb")
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :escape-control)
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
		                                 (skald:span (3 3) "test2 bbb")))))
		                     :test #'equalp)
      
      (swordbreaker:test '(
                           ""
                           "test2 aaa
"
                           "
"
                           "bbb
")
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :no-control)
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
		                                 (skald:span (3 3) "test2 bbb")))))
		                     :test #'equal)
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
	        `(:with-background :green
	           "GREEN_SPAN")))
	    (sleep 1)
	    (skald:skald-draw ()
	      (skald:span (2 12)
	        `(:with-background :blue
	           "BLUE_SPAN")))
	    (sleep 1)
	    (skald:skald-draw ()
	      (skald:span (6 10)
	        `(:with-background :red
	           "RED_SPAN"))))

    (swordbreaker:with-test-group ":DRAW"
      (swordbreaker:test '("\\x1B[0m\\x1B[40m\\x1B[37m\\x1B[2J\\x1B[?25l"
                           "\\x1B[2;2Htest 4 aaa"
                           "\\x1B[2;9Hbbb"
                           "\\x1B[2;2H    \\x1B[2;7H \\x1B[2;9H   \\x1B[3;3Htest 4 ccc")
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :escape-control)
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
                                       "test 4 ccc")))))
		                     :test #'equal)
  
      (swordbreaker:test '(
""
"test 4 aaa
"
 "bbb
"
"          
test 4 ccc
")
                         (skald:with-skald-test (:override-terminal-size '(24 80)
                                                 :debug-mode :no-control)
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
                                       "test 4 ccc")))))
		                     :test #'equal)
      )
  


    (swordbreaker:with-test-group "WRITE-TO-CHANGE-BUFFER tests"
      ;; read the WRITE-TO-CHANGE-BUFFER source code to understand these tests better

   
      (swordbreaker:with-test-group "respect bounding boxes"

        ;; boring single width char insert
        (swordbreaker:test '(#\a #\x #\c #\d #\newline)                       
                           (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                     (skald:with-skald-test (:output nil)
                                       (skald:skald-init)
                                       (skald:skald-draw (:prep)
                                         (skald:span (1 1)
                                           "abcd")))
                                     (skald:with-skald-test (:output nil
                                                             :debug-mode :no-control)
                                       (skald:skald-draw ()
                                         (skald:span (1 2)
                                           #\x))))
                                   'list)
                           :test #'equal)

        ;; don't write outside the bounds of the buffer
        (swordbreaker:test '(#\b #\Newline #\c #\newline)
                           (coerce (skald:with-skald-test (:override-terminal-size '(24 80)
                                                           :output nil
                                                           :debug-mode :no-control)
                                     (skald:skald-init)
                                     (skald:skald-draw ()
                                       (skald:span (1 0)  #\a)
                                       (skald:span (2 1)  #\b)
                                       (skald:span (3 79) #\c)
                                       (skald:span (4 80) #\d)))
                                   'list)
                           :test #'equal)
        
        ;; don't write outside the bounds of a window bounding box
        (swordbreaker:test '((#\Newline)
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
                                                                       :debug-mode :no-control)
                                                 (skald:skald-init)
                                                 (skald:skald-draw ()
                                                   (skald::with-window-bounding-box 2 5 2 5
                                                     (skald::with-point-and-cbox-dimensions row col
                                                       (skald::%render-span "abcd")))))
                                               'list)))
                                   '((1 1)
                                     (2 1)
                                     (2 2)
                                     (2 5)
                                     (6 2)
                                     (6 5)
                                     (7 2)
                                     (7 7)))
                           :test #'equal)
        
        )

      (swordbreaker:with-test-group "double width chars / emoji"
        (assert (eql (code-char #x1F600) #\grinning_face))
        (assert (eql (code-char #x1F610) #\neutral_face))

        ;; boring double width char insert
        (swordbreaker:test '(#\a #\grinning_face #\zero_width_space #\d #\newline)
                           (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                     (skald:with-skald-test (:output nil)
                                       (skald:skald-init)
                                       (skald:skald-draw (:prep)
                                         (skald:span (1 1)
                                           "abcd")))
                                     (skald:with-skald-test (:output nil
                                                             :debug-mode :no-control)
                                       (skald:skald-draw ()
                                         (skald:span (1 2)
                                           #\grinning_face))))
                                   'list)
                           :test #'equal)


        (swordbreaker:with-test-group "inserting a single width char on top of a double width char"
          (swordbreaker:test '(#\replacement_character #\x #\c #\d #\newline)
                             (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                       (skald:with-skald-test (:output nil)
                                         (skald:skald-init)
                                         (skald:skald-draw (:prep)
                                           (skald:span (1 1)
                                             #\grinning_face
                                             "cd")))
                                       (skald:with-skald-test (:output nil
                                                               :debug-mode :no-control)
                                         (skald:skald-draw ()
                                           (skald:span (1 2)
                                             #\x))))
                                     'list)
                             :test #'equal)
          (swordbreaker:test '(#\a #\x #\replacement_character #\d #\newline)
                             (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                       (skald:with-skald-test (:output nil)
                                         (skald:skald-init)
                                         (skald:skald-draw (:prep)
                                           (skald:span (1 1)
                                             #\a
                                             #\grinning_face
                                             #\d)))
                                       (skald:with-skald-test (:output nil
                                                               :debug-mode :no-control)
                                         (skald:skald-draw ()
                                           (skald:span (1 2)
                                             #\x))))
                                     'list)
                             :test #'equal)
          (swordbreaker:test '(#\a #\x #\grinning_face #\zero_width_space #\d #\newline)
                             (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                       (skald:with-skald-test (:output nil)
                                         (skald:skald-init)
                                         (skald:skald-draw (:prep)
                                           (skald:span (1 1)
                                             "ab"
                                             #\grinning_face)))
                                       (skald:with-skald-test (:output nil
                                                               :debug-mode :no-control)
                                         (skald:skald-draw ()
                                           (skald:span (1 2)
                                             #\x))))
                                     'list)
                             :test #'equal)
          )
        

        (swordbreaker:with-test-group "writing single width chars in conflict with both bounding box boundaries & double width char in buffer"

          ;; A+{z  c  d}   >   ? x c d
          (swordbreaker:test '(#\replacement_character #\x #\c #\d #\newline)
                             (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                       (skald:with-skald-test (:output nil)
                                         (skald:skald-init)
                                         (skald:skald-draw (:prep)
                                           (skald:span (1 1)
                                             #\grinning_face
                                             #\c
                                             #\d)))
                                       (skald:with-skald-test (:output nil
                                                               :debug-mode :no-control)
                                         (skald:skald-draw ()
                                           (skald::with-window-bounding-box 1 3 2 3
                                             (skald::with-point-and-cbox-dimensions 1 2
                                               (skald::%render-span #\x))))))
                                     'list)
                             :test #'equal)

          ;;  a {B++z  d}   >   a x ? d
          (swordbreaker:test '(#\a #\x #\replacement_character #\d #\newline)
                             (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                       (skald:with-skald-test (:output nil)
                                         (skald:skald-init)
                                         (skald:skald-draw (:prep)
                                           (skald:span (1 1)
                                             #\a
                                             #\grinning_face
                                             #\d)))
                                       (skald:with-skald-test (:output nil
                                                               :debug-mode :no-control)
                                         (skald:skald-draw ()
                                           (skald::with-window-bounding-box 1 3 2 3
                                             (skald::with-point-and-cbox-dimensions 1 2
                                               (skald::%render-span #\x))))))
                                     'list)
                             :test #'equal)
          ;; a  B+{z  d}  > no op
          (swordbreaker:test '(#\a #\grinning_face #\zero_width_space #\d #\newline)
                             (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                       (skald:with-skald-test (:output nil)
                                         (skald:skald-init)
                                         (skald:skald-draw (:prep)
                                           (skald:span (1 1)
                                             #\a
                                             #\grinning_face
                                             #\d)))
                                       (skald:with-skald-test (:output nil
                                                               :debug-mode :no-control)
                                         (skald:skald-draw ()
                                           (skald::with-window-bounding-box 1 3 3 2
                                             (skald::with-point-and-cbox-dimensions 1 2
                                               (skald::%render-span #\x))))))
                                     'list)
                             :test #'equal)


          ;;  a  B++z {d}  > no op
          (swordbreaker:test '(#\a #\grinning_face #\zero_width_space #\d #\newline)
                             (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                       (skald:with-skald-test (:output nil)
                                         (skald:skald-init)
                                         (skald:skald-draw (:prep)
                                           (skald:span (1 1)
                                             #\a
                                             #\grinning_face
                                             #\d)))
                                       (skald:with-skald-test (:output nil
                                                               :debug-mode :no-control)
                                         (skald:skald-draw ()
                                           (skald::with-window-bounding-box 1 3 4 1
                                             (skald::with-point-and-cbox-dimensions 1 2
                                               (skald::%render-span #\x))))))
                                     'list)
                             :test #'equal)

          ;;  a {B++z} d    >   a x ? d
          (swordbreaker:test '(#\a #\x #\replacement_character #\d #\newline)
                             (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                       (skald:with-skald-test (:output nil)
                                         (skald:skald-init)
                                         (skald:skald-draw (:prep)
                                           (skald:span (1 1)
                                             #\a
                                             #\grinning_face
                                             #\d)))
                                       (skald:with-skald-test (:output nil
                                                               :debug-mode :no-control)
                                         (skald:skald-draw ()
                                           (skald::with-window-bounding-box 1 3 2 2
                                             (skald::with-point-and-cbox-dimensions 1 2
                                               (skald::%render-span #\x))))))
                                     'list)
                             :test #'equal)
          
          ;; {a  B}+z  d    >   a x ? d
          (swordbreaker:test '(#\a #\x #\replacement_character #\d #\newline)
                             (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                       (skald:with-skald-test (:output nil)
                                         (skald:skald-init)
                                         (skald:skald-draw (:prep)
                                           (skald:span (1 1)
                                             #\a
                                             #\grinning_face
                                             #\d)))
                                       (skald:with-skald-test (:output nil
                                                               :debug-mode :no-control)
                                         (skald:skald-draw ()
                                           (skald::with-window-bounding-box 1 3 1 2
                                             (skald::with-point-and-cbox-dimensions 1 2
                                               (skald::%render-span #\x))))))
                                     'list)
                             :test #'equal)
          
          ;; {A++z} c  d    >   ? x c d
          (swordbreaker:test '(#\replacement_character #\x #\c #\d #\newline)
                             (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                       (skald:with-skald-test (:output nil)
                                         (skald:skald-init)
                                         (skald:skald-draw (:prep)
                                           (skald:span (1 1)
                                             #\grinning_face
                                             #\c
                                             #\d)))
                                       (skald:with-skald-test (:output nil
                                                               :debug-mode :no-control)
                                         (skald:skald-draw ()
                                           (skald::with-window-bounding-box 1 3 1 2
                                             (skald::with-point-and-cbox-dimensions 1 2
                                               (skald::%render-span #\x))))))
                                     'list)
                             :test #'equal)
          )
        )

      (swordbreaker:with-test-group "writing double width chars in conflict with bounding box boundaries"
        (swordbreaker:test '((#\a #\grinning_face #\zero_width_space #\d #\newline)
                             (#\a #\grinning_face #\zero_width_space #\d #\newline)
                             (#\a #\b #\c #\d #\newline)
                             (#\a #\b #\c #\d #\newline)
                             (#\a #\grinning_face #\zero_width_space #\d #\newline)
                             (#\a #\replacement_character #\c #\d #\newline))
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
                                                                         :debug-mode :no-control)
                                                   (skald:skald-draw ()
                                                     (skald::with-window-bounding-box 1 2 column width
                                                       (skald::with-point-and-cbox-dimensions 1 2
                                                         (skald::%render-span #\grinning_face))))))
                                               'list)))
                                   '((1 4)
                                     (2 3)
                                     (3 2)
                                     (4 1)
                                     (2 2)
                                     (1 2)))
                           :test #'equal)     
        )

      (swordbreaker:with-test-group "writing double width chars in conflict with both bounding box boundaries & double width char in buffer"

        ;;  A+{z  c  d}   >   ? X+z d
        (swordbreaker:test '(#\replacement_character #\grinning_face #\zero_width_space #\d #\newline)
                           (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                     (skald:with-skald-test (:output nil)
                                       (skald:skald-init)
                                       (skald:skald-draw (:prep)
                                         (skald:span (1 1)
                                           #\grinning_face
                                           #\c
                                           #\d)))
                                     (skald:with-skald-test (:output nil
                                                             :debug-mode :no-control)
                                       (skald:skald-draw ()
                                         (skald::with-window-bounding-box 1 3 2 3
                                           (skald::with-point-and-cbox-dimensions 1 2
                                             (skald::%render-span #\grinning_face))))))
                                   'list)
                           :test #'equal)
        
        ;;  a {B++z  d}   >   a X+z d
        (swordbreaker:test '(#\a #\grinning_face #\zero_width_space #\d #\newline)
                           (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                     (skald:with-skald-test (:output nil)
                                       (skald:skald-init)
                                       (skald:skald-draw (:prep)
                                         (skald:span (1 1)
                                           #\a
                                           #\neutral_face
                                           #\d)))
                                     (skald:with-skald-test (:output nil
                                                             :debug-mode :no-control)
                                       (skald:skald-draw ()
                                         (skald::with-window-bounding-box 1 3 2 3
                                           (skald::with-point-and-cbox-dimensions 1 2
                                             (skald::%render-span #\grinning_face))))))
                                   'list)
                           :test #'equal)
        ;; a  B+{z  d}  > no op
        (swordbreaker:test '(#\a #\grinning_face #\zero_width_space #\d)
                           (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                     (skald:with-skald-test (:output nil)
                                       (skald:skald-init)
                                       (skald:skald-draw (:prep)
                                         (skald:span (1 1)
                                           #\a
                                           #\neutral_face
                                           #\d)))
                                     (skald:with-skald-test (:output nil
                                                             :debug-mode :no-control)
                                       (skald:skald-draw ()
                                         (skald::with-window-bounding-box 1 3 3 2
                                           (skald::with-point-and-cbox-dimensions 1 2
                                             (skald::%render-span #\grinning_face))))))
                                   'list)
                           :test #'equal)


        ;;  a  B++z {d}  > no op
        (swordbreaker:test '(#\a #\neutral_face #\zero_width_space #\d #\newline)
                           (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                     (skald:with-skald-test (:output nil)
                                       (skald:skald-init)
                                       (skald:skald-draw (:prep)
                                         (skald:span (1 1)
                                           #\a
                                           #\neutral_face
                                           #\d)))
                                     (skald:with-skald-test (:output nil
                                                             :debug-mode :no-control)
                                       (skald:skald-draw ()
                                         (skald::with-window-bounding-box 1 3 4 1
                                           (skald::with-point-and-cbox-dimensions 1 2
                                             (skald::%render-span #\grinning_face))))))
                                   'list)
                           :test #'equal)

        
        ;;  a  {B++z} d  >    a X+z d
        (swordbreaker:test '(#\a #\grinning_face #\zero_width_space #\d #\newline)
                           (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                     (skald:with-skald-test (:output nil)
                                       (skald:skald-init)
                                       (skald:skald-draw (:prep)
                                         (skald:span (1 1)
                                           #\a
                                           #\neutral_face
                                           #\d)))
                                     (skald:with-skald-test (:output nil
                                                             :debug-mode :no-control)
                                       (skald:skald-draw ()
                                         (skald::with-window-bounding-box 1 3 4 1
                                           (skald::with-point-and-cbox-dimensions 2 2
                                             (skald::%render-span #\grinning_face))))))
                                   'list)
                           :test #'equal)
        
        ;; {a  b}+c  d    >   a ? ? d
        (swordbreaker:test '(#\a #\replacement_character #\replacement_character #\d #\newline)
                           (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                     (skald:with-skald-test (:output nil)
                                       (skald:skald-init)
                                       (skald:skald-draw (:prep)
                                         (skald:span (1 1)
                                           #\a
                                           #\neutral_face
                                           #\d)))
                                     (skald:with-skald-test (:output nil
                                                             :debug-mode :no-control)
                                       (skald:skald-draw ()
                                         (skald::with-window-bounding-box 1 3 1 2
                                           (skald::with-point-and-cbox-dimensions 1 2
                                             (skald::%render-span #\grinning_face))))))
                                   'list)
                           :test #'equal)
        
        ;; {a++b} c  d    >   ? x c d
        (swordbreaker:test '(#\replacement_character #\replacement_character #\d #\newline)
                           (coerce (skald:with-skald-test (:override-terminal-size '(24 80))
                                     (skald:with-skald-test (:output nil)
                                       (skald:skald-init)
                                       (skald:skald-draw (:prep)
                                         (skald:span (1 1)
                                           #\neutral_face
                                           #\c
                                           #\d)))
                                     (skald:with-skald-test (:output nil
                                                             :debug-mode :no-control)
                                       (skald:skald-draw ()
                                         (skald::with-window-bounding-box 1 3 1 2
                                           (skald::with-point-and-cbox-dimensions 1 2
                                             (skald::%render-span #\grinning_face))))))
                                   'list)
                           :test #'equal)
        )
      )
  


    ))
