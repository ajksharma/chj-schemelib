;;; Copyright 2010, 2011 by Christian Jaeger <chrjae@gmail.com>

;;;    This file is free software; you can redistribute it and/or modify
;;;    it under the terms of the GNU General Public License (GPL) as published 
;;;    by the Free Software Foundation, either version 2 of the License, or
;;;    (at your option) any later version.


;;; a map accepting improper lists (i.e. including non-pairs as l)

(define (improper-map fn l #!optional (tail '()))
  (let rec ((l l))
    (cond ((null? l)
	   tail)
	  ((pair? l)
	   (cons (fn (car l))
		 (rec (cdr l))))
	  (else
	   (fn l)))))

(TEST
 > (improper-map inc '(1 2 3))
 (2 3 4)
 > (improper-map inc '(1 2 . 3))
 (2 3 . 4)
 > (improper-map inc '5)
 6
 > (improper-map inc '())
 ()
 )

(define (improper-fold fn tail l)
  (let lp ((tail tail)
	   (l l))
    (cond ((null? l)
	   tail)
	  ((pair? l)
	   (lp (fn (car l) tail)
	       (cdr l)))
	  (else
	   (fn l tail)))))

(TEST
 > (define (inccons n l)
     (cons (inc n)
	   l))
 > (improper-fold inccons 'end '(1 2 3))
 (4 3 2 . end)
 > (improper-fold inccons 'end '(1 2 . 3))
 (4 3 2 . end)
 )

(define (improper-fold-right fn tail l)
  (let rec ((l l))
    (cond ((null? l)
	   tail)
	  ((pair? l)
	   (fn (car l)
	       (rec (cdr l))))
	  (else
	   (fn l tail)))))

(TEST
 > (improper-fold-right inccons 'end '(1 2 3))
 (2 3 4 . end)
 > (improper-fold-right inccons 'end '(1 2 . 3))
 (2 3 4 . end)
 )

;; improper-fold-right that also tells whether the argument is the end
;; of an improper input list:

(define (improper-fold-right* fn/3 tail l)
  (let rec ((l l))
    (cond ((null? l)
	   tail)
	  ((pair? l)
	   (fn/3 #f
		 (car l)
		 (rec (cdr l))))
	  (else
	   (fn/3 #t
		 l
		 tail)))))

;; test see improper-fold-right/yn-cont in list-util-2.scm


;; destructuring syntax

(define-macro* (let-pair bindform . body)
  (match-list*
   bindform
   ((vars expr)
    (match-list*
     vars
     ((a r)
      (let ((V (gensym)))
	`(let ((,V ,expr))
	   (let ((,a (car ,V))
		 (,r (cdr ,V)))
	     ,@body))))))))

(define-macro* (let-pair* bindforms . body)
  (let rec ((bindforms bindforms))
    (match-list*
     bindforms
     ((bindform . bindforms*)
      `(let-pair ,bindform
		 ,(rec bindforms*)))
     (()
      `(begin ,@body)))))

(define-macro* (lambda-pair bindforms . body)
  ;; for now just support a single argument pair. Should look into
  ;; generalizing lambda-values.
  (match-list*
   bindforms
   ((argpair1)
    ;;(with-gensym V  dependency sigh.
    (let ((V (gensym 'V)))
      (match-list*
       argpair1
       ((a r)
	`(lambda (,V)
	   (let-pair ((,a ,r) ,V)
		     ,@body))))))
   (_
    (source-error
     stx "lambda-pair: only a single argument pair supported for now"))))

(TEST
 > ((lambda-pair ((a b)) (vector a b)) (cons 9 10))
 #(9 10)
 )

(define-macro* (with-pair var* . body)
  (assert* symbol? var*
	   (lambda (var)
	     (let ((l (string-split (symbol->string var) #\.)))
	       (if (= (length l) 2)
		   `(let-pair (,(map string->symbol l) ,var*) ,@body)
		   (source-error
		    var*
		    "variable name does not contain exactly one dot"))))))


(define (fold-right/last fn fnlast tail lis)
  (let rec ((lis lis))
    (let-pair
     ((a lis*) lis)
     (if (null? lis*)
	 (fnlast a tail)
	 (fn a (rec lis*))))))

(TEST
 > (fold-right/last vector cons 'end '(1 2 3))
 #(1 #(2 (3 . end)))
 > (fold-right/last vector cons 'end '(1))
 (1 . end)
 > (with-exception-catcher type-exception?
			   (thunk (fold-right/last vector cons 'end '())))
 #t
 )


(define (map/tail fn tail . liss)
  (apply fold-right
	 (lambda (x tail)
	   (cons (fn x) tail))
	 tail
	 liss))

(TEST
 > (map/tail inc 'mytail '(1 2))
 (2 3 . mytail)
 )




(define-macro* (push! var val)
  `(set! ,var (cons ,val ,var)))



(define (list-preferred lis prefer?)
  (if (pair? lis)
      (let lp ((lis (cdr lis))
	       (min-val (car lis)))
	(cond ((pair? lis)
	       (lp (cdr lis)
		   (let ((val (car lis)))
		     (if (prefer? val
				  min-val)
			 val
			 min-val))))
	      ((null? lis)
	       min-val)
	      (else
	       (error "list-preferred: improper list:" lis))))
      (error "list-preferred: need non-empty list, got:" lis)))

(TEST
 > (list-preferred '(1 3 2 9 -8 3) <)
 -8
 > (list-preferred '(1 3 2 9 -8 3) >)
 9
 > (list-preferred '((1 a) (3 b) (2 c) (9 d) (-8 e) (3 f)) (lambda (a b) (> (car a) (car b))))
 (9 d)
 > (list-preferred '((1 a) (3 b) (2 c) (9 d) (-8 e) (10 f)) (lambda (a b) (> (car a) (car b))))
 (10 f)
 > (list-preferred '((1 a) (3 b) (2 c) (9 d) (-8 e) (9 f)) (lambda (a b) (> (car a) (car b))))
 (9 d)
 )

;; same as list-preferred but also return the list fragments after
;; (including) and before (excluding) the choosen element

(define (split-preferred lis prefer?)
  (if (pair? lis)
      (let lp ((l (cdr lis))
	       (rbefore (cons (car lis) '()))
	       (min-v (car lis))
	       (min-rest lis)
	       (min-rbefore '()))
	(cond ((pair? l)
	       (let* ((v (car l))
		      (r (cdr l))
		      (rbefore* (cons v rbefore)))
		 (if (prefer? v min-v)
		     (lp r rbefore*
			 v
			 l
			 rbefore)
		     (lp r rbefore*
			 min-v
			 min-rest
			 min-rbefore))))
	      ((null? l)
	       (values min-v min-rest min-rbefore))
	      (else
	       (error "improper list ending in:" l))))
      (error "need non-empty list, got:" lis)))
(TEST
 > (values->vector (split-preferred '(1) <))
 #(1 (1) ())
 > (values->vector (split-preferred '(1 2) <))
 #(1 (1 2) ())
 > (values->vector (split-preferred '(2 1) <))
 #(1 (1) (2))
 > (values->vector (split-preferred '(2 1 3) <))
 #(1 (1 3) (2))
 )

;; an append that reverses l1 when appending to l2
(define (rappend l1 l2)
  (let lp ((l1 l1)
	   (l l2))
    (cond ((pair? l1)
	   (lp (cdr l1)
	       (cons (car l1) l)))
	  ((null? l1)
	   l)
	  (else
	   (error "improper list l1 ending in:" l1)))))
(TEST
 > (rappend '() '(3))
 (3)
 > (rappend '(2) '(3))
 (2 3)
 > (rappend '(2 1) '(3))
 (1 2 3)
 )

