

(defpackage :flokkr-test
  (:use :cl :flokkr))


(in-package :flokkr-test)

;; (setf shieldwall:*shieldwall-suppress-errors-p* nil)


(shieldwall:with-shield-group "FLOKKR tests"

  (shieldwall:shield "1 loop"
                     '(1 2 3 4 5)
                     (let ((n 0)
                           accum)
                       (flokkr:flokkr
                         (:do (push (incf n) accum)
                               (when (>= n 5)
                                 (return-from flokkr:flokkr))
                           :schedule 0.001))
                       (nreverse accum)))

  (shieldwall:shield "1 loop + also"
                     '(1 "1" 2 "2" 3 "3" 4 "4" 5)
                     (let ((n 0)
                           accum)
                       (flokkr:flokkr
                         (:do (push (incf n) accum)
                              (when (>= n 5)
                                (return-from flokkr:flokkr))
                          :schedule 0.0001)
                         (:also (push (format nil "~a" n) accum)))
                       (nreverse accum)))
                    

  (shieldwall:shield "2 loops + after + also"
                     '((1 . 0) (2 . 0) (3 . 0) (4 . 0) (5 . 1) (6 . 1) (7 . 2)
                       (8 . 2) (9 . 3) (10 . 3) (11 . 4) (12 . 4) (13 . 5) (14 . 5)
                       (15 . 6) (16 . 6) (17 . 7) (18 . 7) (19 . 8) (20 . 8))
                     (let ((a 0)
                           (b 0)
                           accum)
                       (flokkr:flokkr
                         (:after 0.01 :do (incf a) :repeat)
                         (:after 0.05 :do (incf b) :schedule 0.02)
                         (:also (push (cons a b) accum)
                                (when (>= a  20)
                                  (return-from flokkr:flokkr))))
                       (nreverse accum)))

  (shieldwall:with-shield-group "FLOKKR :DRIFT Tests"


    (shieldwall:shield ":drift causes timer to lag behind scheduled timer"
                       t
                       (let ((a 0)
                             (b 0))
                         (flokkr:flokkr
                           (:after 0.01 :do (incf a) :repeat)
                           (:after 0.05 :do
                                   (sleep 0.005)
                                   (incf b)
                                   :drift 0.02)
                           (:also
                            (when (>= a 20)
                              (return-from flokkr:flokkr))))
                         ;; With :schedule 0.02, b would be ~8-10 after 20 ticks of a
                         ;; With :drift 0.02 + 0.005 work, b should be ~6-7
                         (< b 8)))
    )

  (shieldwall:with-shield-group "FLOKKR :ENFORCE-COOLOFF Tests"

    (shieldwall:shield ":enforce-cooloff applies global delay to maintain synchronization"
                       '(:a-increments-by-more-than-1 nil
                         :final-b 5
                         :a-to-b-ratio-reasonable t)
                       (let ((a 0)
                             (b 0)
                             (prev-a 0)
                             (a-jumped-p nil))
                         (flokkr:flokkr
                           ;; Fast timer: every 0.02s
                           (:after 0.02 :do (incf a) :repeat)
                           ;; Slower timer with enforced cooloff
                           ;; Schedule: 0.06s, work: 0.02s, enforce-cooloff: 0.03s
                           ;; Work (0.02s) + cooloff (0.03s) = 0.05s < schedule (0.06s)
                           ;; So cooloff is satisfiable, but still forces global delay
                           (:after 0.06 :do
                                   (sleep 0.02)  ;; work
                                   (incf b)
                                   :schedule 0.06
                                   :enforce-cooloff 0.03)
                           (:also
                            (when (> (- a prev-a) 1)
                              (setf a-jumped-p t))
                            (setf prev-a a)
                            (when (>= b 5)
                              (return-from flokkr:flokkr))))
                         (list :a-increments-by-more-than-1 a-jumped-p
                               :final-b b
                               :a-to-b-ratio-reasonable (<= 2.0 (/ a b) 4.0))))
    )

  (shieldwall:with-shield-group "SUBFLOKKR tests"

    (shieldwall:shield ":subflokkr without :percolate does not trigger outer :also"
                   '((1 . 2) (2 . 5) (3 . 7) (4 . 10) (5 . 12))
                   (let ((outer 0)
                         (inner 0)
                         accum)
                     (flet ((make-inner-flokkr ()
                              (flokkr:subflokkr
                                (:after 0.02 :do (incf inner) :repeat))))
                       (flokkr:flokkr
                         (:after 0.05 :do (incf outer) :repeat)
                         (:subflokkr (make-inner-flokkr))
                         (:also (push (cons outer inner) accum)
                                (when (>= outer 5)
                                  (return-from flokkr:flokkr)))))
                     (nreverse accum)))

(shieldwall:shield ":subflokkr with :percolate triggers outer :also"
                   '((0 . 1) (0 . 2) (1 . 2) (1 . 3) (1 . 4) (2 . 5))
                   (let ((outer 0)
                         (inner 0)
                         accum)
                     (flet ((make-inner-flokkr ()
                              (flokkr:subflokkr
                                (:after 0.04 :do (incf inner) :repeat))))
                       (flokkr:flokkr
                         (:after 0.1 :do (incf outer) :repeat)
                         (:subflokkr (make-inner-flokkr) :percolate t)
                         (:also (push (cons outer inner) accum)
                                (when (>= inner 5)
                                  (return-from flokkr:flokkr)))))
                     (nreverse accum)))
    )
  )
                     
