;; Copyright 2016-2018 by Christian Jaeger <ch@christianjaeger.ch>

(require easy
	 jclass
	 (cj-gambit-sys maybe-procedure-name maybe-decompile)
	 (list-util let-pair)
	 (cj-functional flip complement)
	 (cj-functional-2 =>) ;; just for fun, in test
	 (cj-match mcase) ;; part of easy?
	 (cj-symbol with-gensym) ;; part of easy?
	 cj-cmp
	 show
	 test)

(export typed-list? ;;
	(jclass typed-list)
	(jclass typed-list-pair)
	(jclass typed-list-cons)
	typed-list-cons
	typed-list-of
	list->typed-list
	typed-list
	(macro typed-list:let-pair)

	(method null
		list
		reverse-list
		filter
		remove
		the
		show
		cons
		prepend
		improper-prepend
		take)
	typed-list:cmp-any)


;; Using the names "first" and "rest" as chosen in functional-perl
;; now, instead of "head" and "tail" like Haskell. Good or bad idea?
;; (See overview of other languages in functional-perl docs.)

(jclass typed-list

	(jclass (typed-list-pair #(procedure? pred)
				 #(natural? length)
				 first
				 rest)

		(def-method (list l)
		  (cons first
			(.list rest)))

		(def-method (reverse-list l #!optional (tail '()))
		  (.reverse-list rest
				 (cons first tail)))

		(def-method- (filter l f)
		  (let-typed-list-pair
		   ((pred _ v r) l)
		   (let ((r* (.filter r f)))
		     (if (f v)
			 ;; tail sharing optimization
			 (if (eq? r* r)
			     l
			     ;; omit type check since already
			     ;; proven right
			     (typed-list-pair pred
					      (inc (.length r*))
					      v
					      r*))
			 r*))))

		(def-method- (remove l f)
		  (typed-list-pair.filter l (complement f)))

		(def-method- (the l
				 #!optional
				 (none (& (error "no element")))
				 (more (& (error "more than one element"))))
		  (let-typed-list-pair
		   ((_ len v _) l)
		   (if (= len 1)
		       v
		       (if (= len 0)
			   (none)
			   (more)))))

		(def-method (null l)
		  (typed-list-null pred)))

	(jclass (typed-list-null #(procedure? pred))

		(def-method- (length l)
		  0)

		(def-method- (list l)
		  '())

		(def-method- (reverse-list l #!optional (tail '()))
		  tail)

		(def-method- (filter l f)
		  l)

		(def-method- (remove l f)
		  l)

		(def-method- (the l)
		  (error "fewer than one element"))

		(def-method- (null l)
		  l))

	(def-method- (show v)
	  `(typed-list ,(.show (.pred v))
		       ,@(map .show (.list v))))

	(def-method- (cons rst fst)
	  (let ((pred (.pred rst)))
	    (if (pred fst)
		(typed-list-pair pred
				 (inc (.length rst))
				 fst
				 rst)
		(error "typed-list: value does not meet predicate:"
		       fst
		       (or (maybe-procedure-name pred)
			   (maybe-decompile pred))))))

	;; XX should actually not be a method since it's generic by
	;; way of .cons anyway?
	(def-method- prepend
	  (named rec
		 (lambda (l v)
		   (cond ((null? v)
			  l)
			 ((pair? v)
			  (let-pair ((val v*) v)
				    (.cons (rec l v*) val)))
			 (else
			  ;; only difference to improper-prepend
			  (error "improper list:" v))))))

	(def-method- improper-prepend
	  (named rec
		 (lambda (l v)
		   (cond ((null? v)
			  l)
			 ((pair? v)
			  (let-pair ((val v*) v)
				    (.cons (rec l v*) val)))
			 (else
			  (.cons l v))))))

	(def-method- (take l #(natural0? n))
	  (let ((len (.length l)))
	    (cond ((= n len)
		   l)
		  ((> n len)
		   (error "list too short (len vs. n):" len n))
		  (else
		   (let rec ((l l) (n n))
		     (if (positive? n)
			 (.cons (rec (.rest l) (dec n))
				(.first l))
			 (.null l))))))))



(def typed-list-cons (flip typed-list.cons))

(def (typed-list-of pred)
     (lambda (v)
       (and (typed-list? v)
	    ;; XX: how to compare type predicates? This is
	    ;; pessimistic.
	    (eq? pred (.pred v)))))

;; don't name list.typed-list, since it can't be dot-oo (with this
;; argument order, and wouldn't make sense (efficiently, and hence at
;; all) otherwise)
(def (list->typed-list pred vals)
     (if (null? vals)
	 (typed-list-null pred)
	 (let-pair ((v vals*) vals)
		   (typed-list-cons v
				    (list->typed-list pred vals*)))))

(def (typed-list pred . vals)
     (list->typed-list pred vals))

(defmacro (typed-list:let-pair bind . body)
  (mcase bind
	 (`(`vars `expr)
	  (mcase vars
		 (`(`a `r)
		  (with-gensym
		   V
		   `(let ((,V ,expr))
		      (let* ((,a (typed-list-pair.first ,V))
			     (,r (@typed-list-pair.rest ,V)))
			,@body))))))))


(TEST
 > (.length (typed-list number? 1 3 4))
 3
 > (.length (typed-list number?))
 0
 > (.list (typed-list number? 1 3 4))
 (1 3 4)
 > (.list (typed-list number? ))
 ()
 > (.list (.cons (.cons (typed-list number?) 10) 11))
 (11 10)
 > (.reverse-list (typed-list number? 1 3 4))
 (4 3 1)
 > (.reverse-list (typed-list number? ))
 ()
 > (%try-error (.list (.cons (.cons (typed-list number?) "10") 11)))
 #(error "typed-list: value does not meet predicate:" "10" number?)
 > (%try-error (.list (.cons (.cons (typed-list number?) 10) "11")))
 #(error "typed-list: value does not meet predicate:" "11" number?)
 > (=> (typed-list number?) (.cons 10) (.cons 11) (.list))
 (11 10))

(TEST
 > (.list (.filter (typed-list number? 1 3 4 5 0) even?))
 (4 0)
 > (.length (.filter (typed-list number? 1 3 4 5 0) even?))
 2
 > (def l (typed-list number? 1 3 4 5 0))
 > (eq? (.filter l natural0?) l)
 #t)

(TEST
 > (.the (typed-list number? 19))
 19
 > (%try-error (.the (typed-list number? )))
 #(error "fewer than one element")
 > (%try-error (.the (typed-list number? 19 20)))
 #(error "more than one element"))

(TEST
 > ((typed-list-of number?) (typed-list number?))
 #t
 ;; currently doesn't allow subtyping...:
 > ((typed-list-of number?) (typed-list integer?))
 #f
 ;; also currently doesn't allow for function redefinitions, bah:
 > ((typed-list-of number?) (typed-list (lambda (v) (number? v))))
 #f)

(TEST
 > (typed-list:let-pair ((a r) (typed-list number? 3 4)) (list a (.list r)))
 (3 (4))
 > (%try-error (typed-list:let-pair ((a r) (cons 3 4)) a))
 #(error "expecting a typed-list-pair, got:" (3 . 4))
 ;; > (%try-error (typed-list:let-pair ((a r) (typed-list-null number?)) a))
 ;; #(error
 ;;   "expecting a typed-list-pair, got:"
 ;;   #((typed-list-null) #<procedure #12 number?>))
 )

(TEST
 > (def z (typed-list number?))
 > (.show (.improper-prepend z '(1 2)))
 (typed-list number? 1 2)
 > (.show (.improper-prepend z '(1 . 2)))
 (typed-list number? 1 2)
 > (.show (.improper-prepend z 3))
 (typed-list number? 3)
 > (%try-error (.show (.improper-prepend z '(a))))
 #(error "typed-list: value does not meet predicate:" a number?))

(TEST
 > (.show (.prepend z '(1 2)))
 (typed-list number? 1 2)
 > (%try-error (.show (.prepend z '(1 . 2))))
 #(error "improper list:" 2))

(TEST
 > (def l (typed-list number? 5 6 7))
 > (.show (.take l 2))
 (typed-list number? 5 6)

 ;; should verify such things rules-based:

 ;; (The length of outputs is the same as n given, or an error
 ;; happens.)
 > (.length (.take l 2))
 2
 > (.length (.take l 3))
 3
 ;; optimizations:
 > (eq? (.take l 3) l)
 #t
 > (%try-error (.take l 4))
 #(error "list too short (len vs. n):" 3 4))


;; adapted copy-paste from cj-cmp.scm
(define (typed-list:cmp-any cmp)
  (named lp (lambda (l1 l2)
	      (if (typed-list-null? l1)
		  (if (typed-list-null? l2)
		      'eq
		      'lt)
		  (if (typed-list-null? l2)
		      'gt
		      (typed-list:let-pair
		       ((a l1*) l1)
		       (typed-list:let-pair
			((b l2*) l2)
			(match-cmp (cmp a b)
				   ((eq) (lp l1* l2*))
				   ((lt) 'lt)
				   ((gt) 'gt)))))))))
