

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
                           :reschedule 0.001))
                       (nreverse accum)))

  (shieldwall:shield "1 loop + also"
                     '(1 "1" 2 "2" 3 "3" 4 "4" 5)
                     (let ((n 0)
                           accum)
                       (flokkr:flokkr
                         (:do (push (incf n) accum)
                              (when (>= n 5)
                                (return-from flokkr:flokkr))
                          :reschedule 0.0001)
                         (:also (push (format nil "~a" n) accum)))
                       (nreverse accum)))
                    

  ;; <<>> investigate this

  
  (shieldwall:shield "2 loops + after + also"
                     '((1 . 0) (2 . 0) (3 . 0) (4 . 0)
                       (5 . 1) (6 . 1) (7 . 1) (8 . 1)
                       (9 . 2) (10 . 2) (11 . 2) (12 . 2)
                       (13 . 3) (14 . 3) (15 . 3) (16 . 3)
                       (17 . 4) (18 . 4) (19 . 4) (20 . 4) (21 . 5))
                     (let ((a 0)
                           (b 0)
                           accum)
                       (flokkr:flokkr
                         (:after 0.01 :do (incf b) :reschedule 0.01)
                         (:do (incf a) :reschedule 0.002)
                         (:also (push (cons a b) accum)
                                (when (>= b  5)
                                  (return-from flokkr:flokkr))))
                       (nreverse accum)))

  (shieldwall:shield "2 loops + after + also"
                     '((1 . 0) (2 . 0) (3 . 0) (4 . 0) (5 . 0)
                       (5 . 1) (6 . 1) (7 . 1) (8 . 1) (9 . 1)
                       (9 . 2) (10 . 2) (11 . 2) (12 . 2) (13 . 2)
                       (13 . 3) (14 . 3) (15 . 3) (16 . 3) (17 . 3)
                       (17 . 4) (18 . 4) (19 . 4) (20 . 4) (21 . 5))`
                     (let ((a 0)
                           (b 0)
                           accum)
                       (flokkr:flokkr
                         (:do (incf a) :reschedule 0.002)
                         (:after 0.01 :do (incf b) :reschedule 0.01)
                         (:also (push (cons a b) accum)
                                (when (>= b  5)
                                  (return-from flokkr:flokkr))))
                       (nreverse accum)))


  
  
  )
                     
