(require easy
	 more-oo
	 test)

(class Maybe
       (subclass Nothing
		 (struct constructor-name: _Nothing))

       (subclass Just
		 (struct value)))

;; optimization:
(def __Nothing (_Nothing))
(def (Nothing)
     __Nothing)

(TEST
 > (eq? (Nothing) (Nothing))
 #t
 > (map (lambda (v)
	  (map (C _ v) (list Maybe? Nothing? Just?
			     (lambda (v)
			       (if (Just? v)
				   (Just.value v)
				   'n)))))
	(list #f
	      (values)
	      (Nothing)
	      (Just 1)
	      (Just #f)
	      (Just (Nothing))
	      (Just (Just 13))))
 ((#f #f #f n)
  (#f #f #f n)
  (#t #t #f n)
  (#t #f #t 1)
  (#t #f #t #f)
  (#t #f #t #(Nothing))
  (#t #f #t #(Just 13)))
 > (Just.value (.value (Just (Just 13))))
 13)



(def (if-Maybe #(Maybe? v) then else)
     (if (Just? v)
	 (then (Just.value v))
	 (else)))


(defmacro (Maybe:if t
		    then
		    #!optional
		    else)
  `(if-Maybe ,t ,then (lambda () ,(or else `(void)))))

(defmacro (Maybe:cond t+then #!optional else)
  (mcase t+then
	 (`(`t => `then)
	  `(if-Maybe ,t
		     ,then
		     (lambda ()
		       ,(if else
			    (mcase else
				   (`(else `else)
				    else))
			    `(void)))))))

(TEST
 > (def (psqrt x)
	(if (positive? x)
	    (Just (sqrt x))
	    (Nothing)))
 > (def (f x)
	(Maybe:if (psqrt x)
		  inc
		  'n))
 > (def (f* x)
	(Maybe:if (psqrt x)
		  inc))
 > (def (g x)
	(Maybe:cond ((psqrt x) => inc)
		    (else 'n)))
 > (def (g* x)
	(Maybe:cond ((psqrt x) => inc)))
 > (map (lambda (x)
	  (list (f x)
		(g x)
		(f* x)
		(g* x)))
	(list 4 9 -4))
 ((3 3 3 3)
  (4 4 4 4)
  (n n #!void #!void))
 > (%try-error (Maybe:cond ((sqrt 4) => inc)))
 #(error "v does not match Maybe?:" 2))


(def (Maybe pred)
     (lambda (v)
       (or (Nothing? v)
	   (and (Just? v)
		(pred (Just.value v))))))

(TEST
 > (def Maybe-integer? (Maybe integer?))
 > (map Maybe-integer? (list (Nothing) 10 (Just 10)))
 (#t #f #t))
