


;; (require :bifrost)
;; (require :swordbreaker)

(defpackage :bifrost-test
  (:use :cl :bifrost))

(in-package :bifrost-test)

;;  (setf swordbreaker::*muffle-test-errors-p* nil)
(setf swordbreaker::*muffle-test-errors-p* t)

(swordbreaker:with-test-group "bifrost tests"

  (swordbreaker:with-test-group "RUNE-READ"

    (with-input-from-string (in "abc") ;; ok
      (bifrost:flush-rune-read-buffer)
      (swordbreaker:test #\a (bifrost:rune-read-raw-no-hang in))
      (swordbreaker:test #\b (bifrost:rune-read-raw-no-hang in))
      (swordbreaker:test #\c (bifrost:rune-read-raw-no-hang in))
      (swordbreaker:test nil (bifrost:rune-read-raw-no-hang in))
      )

    ;; good escape sequence
    (with-input-from-string (in (format nil "~A[<0;2;3M" #\Esc)) ;; ok
      (bifrost:flush-rune-read-buffer)
      (swordbreaker:test '(:mouse-click-left 3 2)
                         (bifrost:rune-read-raw-no-hang in)
                         :test #'equalp)
      (swordbreaker:test nil (bifrost:rune-read-raw-no-hang in))
      )

    ;;;; not yet supported
    ;;
    ;; (with-input-from-string (in (format nil "~A[10;20R" #\Esc))
    ;;   (bifrost:flush-rune-read-buffer)
    ;;   (swordbreaker:test '(:cursor-position 10 20)
    ;;                      (bifrost:rune-read-raw-no-hang in)
    ;;                      :test #'equalp)
    ;;   (swordbreaker:test nil (bifrost:rune-read-raw-no-hang in)))


    ;; bad escape sequence
    (with-input-from-string (in (format nil "~A[XX;2;3M" #\Esc)) ;; ok
      (bifrost:flush-rune-read-buffer)
      (swordbreaker:test #\Esc (bifrost:rune-read-raw-no-hang in))
      (swordbreaker:test #\[ (bifrost:rune-read-raw-no-hang in))
      (swordbreaker:test #\X (bifrost:rune-read-raw-no-hang in))
      )

    ;; debugging mode
    (with-input-from-string (in (format nil "abc~Adef" #\newline)) ;; ok
      (let ((bifrost:*rune-read-debug-mode* t))
        (declare (special bifrost:*rune-read-debug-mode*))
        (bifrost:flush-rune-read-buffer)
        (swordbreaker:test #\a (bifrost:rune-read-raw-no-hang in))
        (swordbreaker:test '(#\b #\c)
                           (bifrost::fifo-char-buffer-first bifrost::*rune-read-buffer*)
                           :test #'equalp)
        (swordbreaker:test #\b (bifrost:rune-read-raw-no-hang in))
        (swordbreaker:test #\c (bifrost:rune-read-raw-no-hang in))
        (swordbreaker:test #\d (bifrost:rune-read-raw-no-hang in))
        ))

    ;; debugging mode: rune literals
    (with-input-from-string (in (format nil "~A(:name row column)b~Ac" #\~ #\Newline))  ;; locks everything ok
      (let ((bifrost:*rune-read-debug-mode* nil))
        (declare (special bifrost:*rune-read-debug-mode*))
          (bifrost:flush-rune-read-buffer)
        (swordbreaker:test #\~
                           (bifrost:rune-read-raw-no-hang in))
        (swordbreaker:test '(#\( #\: #\n #\a #\m #\e #\space #\r #\o #\w #\space #\c #\o #\l #\u #\m #\n #\) #\b #\newline #\c)
                           (bifrost::fifo-char-buffer-first bifrost::*rune-read-buffer*)
                           :test #'equalp)
        ))

    (with-input-from-string (in (format nil "a~A(:name row column)b~Ac" #\~ #\Newline)) ;; ok
      (let ((bifrost:*rune-read-debug-mode* t))
        (declare (special bifrost:*rune-read-debug-mode*))
        (bifrost:flush-rune-read-buffer)
        (swordbreaker:test #\a
                           (bifrost:rune-read-raw-no-hang in))
        (swordbreaker:test '(#\~ #\( #\: #\n #\a #\m #\e #\space #\r #\o #\w #\space #\c #\o #\l #\u #\m #\n #\) #\b)
                           (bifrost::fifo-char-buffer-first bifrost::*rune-read-buffer*)
                           :test #'equalp)

      ))

    (with-input-from-string (in "~(:mouse-click-left 5 6)abc") ;; ok
      (let ((bifrost:*rune-read-debug-mode* t))
        (declare (special bifrost:*rune-read-debug-mode*))
        (bifrost:flush-rune-read-buffer)
        (swordbreaker:test '(:mouse-click-left 5 6)
                           (bifrost:rune-read-raw-no-hang in)
                           :test #'equalp)
        ))

    
    )

  (swordbreaker:with-test-group "RUNE-CASE"
    (swordbreaker:test 1
                       (bifrost:rune-case #\a
                         (#\a 1)
                         (#\b 2)
                         (:mouse-click-left 3)
                         (otherwise 4)))
    (swordbreaker:test 2
                       (bifrost:rune-case #\b
                         (#\a 1)
                         (#\b 2)
                         (:mouse-click-left 3)
                         (otherwise 4)))
    (swordbreaker:test 3
                       (bifrost:rune-case '(:mouse-click-left 10 11)
                         (#\a 1)
                         (#\b 2)
                         (:mouse-click-left 3)
                         (otherwise 4)))
    (swordbreaker:test 4
                       (bifrost:rune-case '(:mouse-click-left 10 11)
                         (#\a 1)
                         (#\b 2)
                         (:mouse-click-left-unrelease 3)
                         (otherwise 4)))                         
    )

  (swordbreaker:with-test-group "RUNE-WRITE"

    (swordbreaker:test "z"
                       (with-output-to-string (out)
                         (bifrost:rune-write #\z out))
                       :test #'equal)
      
    (swordbreaker:test (format nil "~A[2J" #\Esc)
                       (with-output-to-string (out)
                         (rune-write :clear out))
                       :test #'equal)

    (swordbreaker:test (format nil "~A[0m" #\Esc)
                       (with-output-to-string (out)
                         (rune-write :reset out))
                       :test #'equal)

    (swordbreaker:test (format nil "~A[?25l" #\Esc)
                       (with-output-to-string (out)
                         (rune-write :hide-cursor out))
                       :test #'equal)

    (swordbreaker:test (format nil "~A[?25h" #\Esc)
                       (with-output-to-string (out)
                         (rune-write :unhide-cursor out))
                       :test #'equal)

    (swordbreaker:test (format nil "~A[33m" #\Esc)
                       (with-output-to-string (out)
                         (rune-write '(:foreground 3) out))
                       :test #'equal)

    (swordbreaker:test (format nil "~A[44m" #\Esc)
                       (with-output-to-string (out)
                         (rune-write '(:background 4) out))
                       :test #'equal)

    (swordbreaker:test (format nil "~A[H" #\Esc)
                       (with-output-to-string (out)
                         (rune-write :move-cursor out))
                       :test #'equal)

    
    (swordbreaker:test (format nil "~A[10;20H" #\Esc)
                       (with-output-to-string (out)
                         (rune-write '(:move-cursor 10 20) out))
                       :test #'equal)

    ;; Test nudging the cursor relatively; for example, nudge 2 rows down and 3 columns left.
    (swordbreaker:test (concatenate 'string
                                    (format nil "~A[2B" #\Esc)
                                    (format nil "~A[3D" #\Esc))
                       (with-output-to-string (out)
                         (rune-write '(:nudge-cursor 2 -3) out))
                       :test #'equal)
  
    (swordbreaker:test (format nil "~A[?1006h" #\Esc)
                       (with-output-to-string (out)
                         (rune-write '(:sgr-mouse-reporting t) out))
                       :test #'equal)

    (swordbreaker:test (format nil "~A[?1006l" #\Esc)
                       (with-output-to-string (out)
                         (rune-write '(:sgr-mouse-reporting nil) out))
                       :test #'equal)

    (swordbreaker:test (format nil "~A[?1000h" #\Esc)
                       (with-output-to-string (out)
                         (rune-write '(:mouse-reporting 1000 t) out))
                       :test #'equal)

    (swordbreaker:test (format nil "~A[?1000l" #\Esc)
                       (with-output-to-string (out)
                         (rune-write '(:mouse-reporting 1000 nil) out))
                       :test #'equal)


    (swordbreaker:with-test-group "RUNE-WRITE-RAW queries"
      (swordbreaker:test (format nil "~A[18t" #\Esc)
                         (with-output-to-string (out)
                           (rune-write-raw :query-terminal-size out))
                         :test #'equal)

      (swordbreaker:test (format nil "~A[6n" #\esc)
                         (with-output-to-string (out)
                           (rune-write-raw :query-cursor-position out))
                         :test #'equal)
      )
    
    )
  

  (swordbreaker:with-test-group "RUNE-READ"

    (let ((*bifrost-mouse-tracking-mode* 1000))
      (declare (special *bifrost-mouse-tracking-mode*))
      (with-input-from-string (in "def")
        (bifrost:flush-rune-read-buffer)
        (bifrost:with-cbox t
          (swordbreaker:test #\d
                             (bifrost:rune-read-no-hang in))
          )))

    (with-input-from-string (in (format nil "~A[8;4;5t" #\Esc))
      (bifrost:flush-rune-read-buffer)
      (swordbreaker:test '(:terminal-size 4 5)
                         (bifrost:rune-read-no-hang in)
                         :test #'equalp)
      )
    
    (swordbreaker:with-test-group "RUNE-READ mouse clicks"


    (let ((*bifrost-mouse-tracking-mode* 1000))
      (declare (special *bifrost-mouse-tracking-mode*))
      (with-input-from-string (in (format nil "~A[<0;2;3M" #\Esc))
        (bifrost:flush-rune-read-buffer)
        (bifrost:with-cbox t
          (swordbreaker:test '(:mouse-click-left 3 2)
                             (bifrost:rune-read-no-hang in)
                             :test #'equalp)
          (swordbreaker:test nil
                             (bifrost:rune-read-no-hang in))
      )))

      
      (let ((*bifrost-mouse-tracking-mode* 1000))
        (declare (special *bifrost-mouse-tracking-mode*))
        (bifrost:with-cbox t
          (bifrost:register-cbox! :test-cbox-1 
                                  :min-row    3
                                  :min-column 3
                                  :max-row    6
                                  :max-column 6)
          (flet ((%click (r c)
                   (with-input-from-string (in (format nil
                                                       "~A[<0;~A;~AM"
                                                       #\Esc
                                                       r
                                                       c))
                     (bifrost:flush-rune-read-buffer)
                     (bifrost:rune-read-no-hang in))))

            (swordbreaker:test '(:mouse-click-left 2 2)
                               (%click 2 2)
                               :test #'equalp)
            (swordbreaker:test '(:cbox-click-left 3 3)
                               (%click 3 3)
                               :test #'equalp)
            (swordbreaker:test '(:cbox-click-left 4 4)
                               (%click 4 4)
                               :test #'equalp)
            (swordbreaker:test '(:mouse-click-left 6 6)
                               (%click 6 6)
                               :test #'equalp)
            (swordbreaker:test '(:mouse-click-left 7 7)
                               (%click 7 7)
                               :test #'equalp)
            )))
      )
    )
  

  
  )
