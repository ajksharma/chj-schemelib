;;; Copyright 2010-2014 by Christian Jaeger <chrjae@gmail.com>

;;;    This file is free software; you can redistribute it and/or modify
;;;    it under the terms of the GNU General Public License (GPL) as published 
;;;    by the Free Software Foundation, either version 2 of the License, or
;;;    (at your option) any later version.


(require define-macro-star
	 test
	 simple-match
	 cj-inline
	 cj-symbol
	 enum)


(define-enum cmp
  eq lt gt)

(TEST
 > (cmp? 'a)  #f
 > (cmp? 'LT) #f
 > (cmp? 'lt) #t
 > (cmp? 'gt) #t
 > (cmp? 'eq) #t)



;; A comparison operation working for all types in question

;; I'm choosing this sort order for mixed-type comparisons:
;; booleans < numbers < symbols < strings < other-types

(define (cmp:type-of v)
  (cond ((boolean? v)
	 1)
	((number? v)
	 2)
	((symbol? v)
	 3)
	((string? v)
	 4)
	(else
	 ;; generic
	 9999)))

;; universal element predicate:
(define (element? v)
  (or (boolean? v)
      (number? v)
      (symbol? v)
      (string? v)))

(define-inline (@boolean-cmp v1 v2)
  ;; #f < #t
  (cond ((eq? v1 v2)
	 'eq)
	((eq? v1 #f)
	 'lt)
	(else
	 'gt)))
(define-inline (@number-cmp v1 v2)
  (cond ((< v1 v2)
	 'lt)
	((< v2 v1)
	 'gt)
	(else
	 'eq)))
(define-inline (@symbol-cmp v1 v2)
  (cond ((eq? v1 v2)
	 'eq)
	(else
	 ;; sort by their string representation
	 (string-cmp (symbol->string v1)
		     (symbol->string v2)))))
(define-inline (@string-cmp v1 v2)
  (cond ((string<? v1 v2)
	 'lt)
	((string<? v2 v1)
	 'gt)
	(else
	 'eq)))
;; make safe wrappers:
(insert-result-of
 (cons 'begin
       (map (lambda (typ)
	      (let ((typ? (symbol-append typ "?")))
		`(define (,(symbol-append typ "-cmp") v1 v2)
		   (define (err v)
		     (error ,(string-append "not a " typ ":") v))
		   (if (,typ? v1)
		       (if (,typ? v2)
			   (,(symbol-append "@" typ "-cmp") v1 v2)
			   (err v2))
		       (err v1)))))
	    '("boolean" "number" "symbol" "string"))))

(define (u8vector-cmp v1 v2)
  ;; Gambit doesn't offer u8vector>? or similar, so..
  (let ((l1 (u8vector-length v1))
	(l2 (u8vector-length v2)))
    (let ((l (min l1 l2)))
      (let lp ((i 0))
	(if (= i l)
	    (cond ((= l1 l2)
		   'eq)
		  ((< l1 l2)
		   'lt)
		  (else
		   'gt))
	    (let ((b1 (u8vector-ref v1 i))
		  (b2 (u8vector-ref v2 i)))
	      (cond ((< b1 b2)
		     'lt)
		    ((< b2 b1)
		     'gt)
		    (else
		     (lp (inc i))))))))))
(TEST
 > (u8vector-cmp (u8vector) (u8vector))
 eq
 > (u8vector-cmp (u8vector 1) (u8vector 1))
 eq
 > (u8vector-cmp (u8vector 1) (u8vector 2))
 lt
 > (u8vector-cmp (u8vector 1 2) (u8vector 2))
 lt
 > (u8vector-cmp (u8vector 1 2 3) (u8vector 1 2))
 gt
 )

(define (generic-cmp v1 v2)
  (if (eq? v1 v2)
      'eq
      (let ((t1 (cmp:type-of v1))
	    (t2 (cmp:type-of v2)))
	(if (eq? t1 t2)
	    (case t1
	      ((1) (@boolean-cmp v1 v2))
	      ((2) (@number-cmp v1 v2))
	      ((3) (@symbol-cmp v1 v2))
	      ((4) (@string-cmp v1 v2))
	      (else
	       ;; fully generic; XXX I expect this to be slow;
	       ;; (object->string doesn't work correclty for objects
	       ;; with a serial number)
	       (u8vector-cmp (object->u8vector v1)
			     (object->u8vector v2))))
	    (cond ((< t1 t2)
		   'lt)
		  ((< t2 t1)
		   'gt)
		  (else
		   (error "BUG")))))))


(define (xserial-number v)
  (if (##mem-allocated? v)
      (object->serial-number v)
      (error "not memory-allocated:" v)))
(define (pointer-cmp v1 v2)
  ;; use a let to force evaluation order of the arguments
  (let ((s1 (xserial-number v1)))
    (number-cmp s1
		(xserial-number v2))))

(TEST
 > (generic-cmp #f #f)
 eq
 > (generic-cmp #f #t)
 lt
 > (generic-cmp #t #f)
 gt
 > (generic-cmp 1 1)
 eq
 > (generic-cmp 1 1.)
 eq ;; well. But yeah, whatever numeric comparison thinks.
 > (generic-cmp 1 2)
 lt
 > (generic-cmp 2 0)
 gt
 > (generic-cmp 2 "Hello")
 lt
 > (generic-cmp "Hello" 2)
 gt
 > (generic-cmp "Hello" "World")
 lt
 > (generic-cmp "Hello" "abc")
 lt ;; A lt a
 > (generic-cmp "Hello" 'abc)
 gt
 > (generic-cmp 'cde 'abc)
 gt
 > (generic-cmp 'cde 'cde)
 eq
 > (generic-cmp 'b 'cde)
 lt

 ;; other types:
 > (define-type foo a)
 > (generic-cmp (make-foo 1)(make-foo 1))
 eq
 > (generic-cmp (make-foo 1)(make-foo 3))
 lt
 > (generic-cmp (make-foo 3)(make-foo 1))
 gt

 ;; a little hacky, relies on fresh instances and increasing serial numbers
 > (pointer-cmp (make-foo 1)(make-foo 1))
 lt
 > (pointer-cmp (make-foo 1)(make-foo 3))
 lt
 > (pointer-cmp (make-foo 3)(make-foo 1))
 lt
 > (define a (make-foo 1))
 > (define b (make-foo 1))
 > (pointer-cmp a b)
 lt
 > (pointer-cmp b a)
 gt
 > (pointer-cmp a a)
 eq
 > (pointer-cmp b b)
 eq
 )

(define-macro* (match-cmp v . cases)
  (let ((V (gensym 'v)))
    `(let ((,V ,v))
       (case ,V
	 ,@(append
	    (map (lambda (c)
		   (match-list*
		    c
		    ((symbol-list body0 . body)
		     (match-list*
		      symbol-list
		      ;; for proper list checking and location removal
		      (symbols
		       (for-each (lambda (s)
				   (if (not (memq (source-code s) '(lt gt eq)))
				       (source-error s "expecting one of |lt|, |gt|, |eq|")))
				 symbols)
		       `(,symbols ,body0 ,@body))))))
		 cases)
	    `((else (match-cmp-error ,V))))))))

(define (match-cmp-error v)
  (error "match-cmp: no match for:" v))

(TEST
 > (match-cmp (generic-cmp 1 2) ((lt) "ha"))
 "ha"
 > (match-cmp (generic-cmp 2 1) ((lt gt) "unequal") ((eq) "equal"))
 "unequal"
 > (match-cmp (generic-cmp 2 2) ((lt gt) "unequal") ((eq) "equal"))
 "equal"
 > (with-exception-catcher
    error-exception-message
    (lambda () (match-cmp (generic-cmp 2 1) ((lt) "unequal") ((eq) "equal"))))
 "match-cmp: no match for:"
 )

;; XX move these somewhere else?

(define (cmp->equal? cmp)
  (lambda (a b)
    (match-cmp (cmp a b)
	       ((eq)
		#t)
	       ((lt gt)
		#f))))

(define (cmp->lt? cmp)
  (lambda (a b)
    (match-cmp (cmp a b)
	       ((lt)
		#t)
	       ((eq gt)
		#f))))

(define (lt->cmp lt)
  (lambda (v1 v2)
   (cond ((lt v1 v2)
	  'lt)
	 ((lt v2 v1)
	  'gt)
	 (else
	  'eq))))

;; (could be optimized slightly by changing sort)
(define (cmp-sort l cmp)
  (sort l (cmp->lt? cmp)))


(define (cmp-not v)
  (match-cmp v
	     ((eq) 'eq)
	     ((lt) 'gt)
	     ((gt) 'lt)))

(define (cmp-complement cmp)
  (lambda (a b)
    (cmp-not (cmp a b))))


(define (cmp-either cmp1 cmp2)
  ;; run cmp2 if cmp1 gave eq (i.e. treat eq as |either| would #f)
  (lambda (a b)
    (match-cmp (cmp1 a b)
	       ((eq)
		(cmp2 a b))
	       ((lt) 'lt)
	       ((gt) 'gt))))

(TEST
 > ((cmp-either (on car string-cmp) (on cadr number-cmp)) '("a" 10) '("a" -2))
 gt
 > ((cmp-either (on car string-cmp) (on cadr number-cmp)) '("a" -10) '("a" -2))
 lt
 > ((cmp-either (on car string-cmp) (on cadr number-cmp)) '("b" -10) '("a" -2))
 gt
 > ((cmp-either (on car string-cmp) (on cadr number-cmp)) '("b" -10) '("a" 2))
 gt
 )

;; --- keep this?
;; turn multiple cmps into a new cmp, that compares by the cmps in
;; order of the list until one not returning eq is found
(define (2cmp cmp1 cmp2)
  (lambda (a b)
    (match-cmp (cmp1 a b)
	       ((lt) 'lt)
	       ((gt) 'gt)
	       ((eq) (cmp2 a b)))))

(define cmp-always-eq
  (lambda (a b)
    'eq))

(define (list-cmps->cmp cmps)
  (fold-right 2cmp
	      cmp-always-eq
	      cmps))

(define (cmps->cmp . cmps)
  (list-cmps->cmp cmps))

;; (TEST
;;  )

;; --- /keep this?

(define-macro* (cmp-or . exprs)
  (if (null? exprs)
      `'eq
      `(match-cmp ,(car exprs)
		  ((eq) (cmp-or ,@(cdr exprs)))
		  ((lt) 'lt)
		  ((gt) 'gt))))

;; case-insensitive and umlaut sensitive comparison

(define (german-char-downcase c) ;; german-to-lower
  (define upper "ÄÖÜÇÉÈÀ")
  (define lower "äöüçéèà")
  (let ((len (string-length lower)))
    (let lp ((i 0))
      (if (< i len)
	  (if (char=? (string-ref upper i) c)
	      (string-ref lower i)
	      (lp (inc i)))
	  (char-downcase c)))))

(define (char-cmp a b)
  (if (char=? a b)
      'eq
      (if (char>? a b)
	  'gt
	  'lt)))

;; these only work for lower case (use german-char-downcase)
(define (lc_perhaps-compound-1st c)
  (case c
    ((#\ä) #\a)
    ((#\ö) #\o)
    ((#\ü) #\u)
    ((#\ç) #\c)
    ((#\é) #\e)
    ((#\è) #\e)
    ((#\à) #\a)
    (else
     c)))

;; XX ah and then not even bother to look at the second? for now?
;; anyway:
(define (lc_umlaut? c)
  (case c
    ((#\ä #\ö #\ü) #t)
    (else
     #f)))

;; fix up the strings on the fly (instead of building index containing
;; massaged strings); or, compare them on the fly? [is there any
;; difference?]
(define (german-string-cmp a b)
  (if (and (string? a)
	   (string? b))
      (let ((lena (string-length a))
	    (lenb (string-length b)))
	(let lp ((ia 0)
		 (ib 0))
	  (if (< ia lena)
	      (if (< ib lenb)
		  ;; XX ignore ö vs oe for now; treat ö same as o
		  (let ((ca (lc_perhaps-compound-1st;; for now
			     (german-char-downcase (string-ref a ia))))
			(cb (lc_perhaps-compound-1st;; for now
			     (german-char-downcase (string-ref b ib)))))
		    (cmp-or (char-cmp ca cb)
			    (lp (inc ia)
				(inc ib))))
		  'gt)
	      (if (< ib lenb)
		  'lt
		  'eq))))))

(TEST
 > (german-string-cmp "Hallo" "hallo")
 eq
 > (german-string-cmp "Hallo" "hallochen")
 lt
 > (german-string-cmp "Öchsel" "öchsel")
 eq
 > (german-string-cmp "Öchsel" "Ochsel")
 eq ;; hmm yeh hmm
 > (german-string-cmp "Öchsel" "Oechsel")
 lt ;; XX should not be. or?
 )

;; only 'german' for strings [for now?]
(define (german-generic-cmp a b)
  (if (and (string? a)
	   (string? b))
      (german-string-cmp a b)
      (generic-cmp a b)))
