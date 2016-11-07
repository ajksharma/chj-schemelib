(require easy
	 test)

(export (macro iflet)
	(macro if-let*)
	(macro if-let))


(defmacro (iflet bind+test yes #!optional no)
  (mcase bind+test
	 (`(`var `test)
	  (assert* symbol? var)
	  `(cond (,test => (lambda (,var) ,yes))
		 (else ,no)))))

(TEST
 > (iflet (a 2) 3)
 3
 > (iflet (a 2) a)
 2
 > (iflet (a 2) a 4)
 2
 > (iflet (a #f) a 4)
 4)


(defmacro (if-let* #((source-of list?) assignments) yes #!optional no)
  (with-gensym
   NO
   `(let ((,NO (lambda () ,no)))
      ,(fold-right (lambda (assignment yes)
		     (mcase assignment
			    (`(`var `test-expr)
			     (assert* symbol? var)
			     `(cond (,test-expr => (lambda (,var) ,yes))
				    (else (,NO))))))
		   yes
		   (source-code assignments)))))

(TEST
 > (if-let* ((a 2)) 3)
 3
 > (if-let* ((a 2)) a)
 2
 > (if-let* ((a 2)) a 4)
 2
 > (if-let* ((a #f)) a 4)
 4
 > (if-let* ((a 2)
	     (b 3))
	    (list a b)
	    4)
 (2 3)
 > (def (f x)
	(if-let* ((a (and x (* x x)))
		  (b (dec a))
		  (c (< b 10))
		  (d (list a b)))
		 d
		 'no))
 > (f #f)
 no
 > (f 10)
 no
 > (f 2)
 (4 3)
 > (%try (if-let* ((GEN:-11015 #f)
		   (b 3))
		  (list a b)
		  GEN:-11015))
 (exception text: "Unbound variable: GEN:-11015\n"))



;; same as if-let* (and still currently short-cuts evaluation the same
;; way, i.e. currently doesn't "allow" for parallel evaluation,
;; although should we keep that open? Or different forms for that?
;; Probably?)  but don't make the variables visible to "subsequent"
;; terms, only to `yes`
(defmacro (if-let #((source-of list?) assignments) yes #!optional no)
  (let* ((assignments* (source-code assignments))
	 (assignments** (map (lambda (assignment)
			       (mcase assignment
				      (`(`var `test-expr)
				       (assert* symbol? var
						(lambda (var*)
						  (values var test-expr (gensym var*)))))))
			     assignments*)))
    (with-gensym
     NO
     `(let ((,NO (lambda () ,no)))
	,(fold-right (lambda-values
		      ((var test-expr tmpvar) yes)
		      `(cond (,test-expr => (lambda (,tmpvar) ,yes))
			     (else (,NO))))
		     `(let ,(map (lambda-values
				  ((var test-expr tmpvar))
				  `(,var ,tmpvar))
				 assignments**)
			,yes)
		     assignments**)))))

(TEST
 > (if-let ((a 2)) 3)
 3
 > (if-let ((a 2)) a)
 2
 > (if-let ((a 2)) a 4)
 2
 > (if-let ((a #f)) a 4)
 4
 > (if-let ((a 2)
	    (b 3))
	   (list a b)
	   4)
 (2 3)
 > (%try (let ((x 10))
	   (if-let ((GEN:a-10740 (and x (* x x)))
		    (GEN:b-10741 (dec GEN:a-10740))
		    (GEN:c-10742 (< GEN:b-10741 10))
		    (d (list GEN:a-10740 GEN:b-10741)))
		   d
		   'no)))
 (exception text: "Unbound variable: GEN:a-10740\n")
 > (def (f x)
	(let ((a 100)
	      (b x))
	  (if-let ((a (and x (* x x)))
		   (b (dec a))
		   (c (< b 10))
		   (d (list a b)))
		  d
		  'no)))
 > (f #f)
 no
 > (f 10)
 no
 > (f 2)
 (100 2)
 > (%try (if-let ((GEN:-11015 #f)
		  (b 3))
		 (list a b)
		 GEN:-11015))
 (exception text: "Unbound variable: GEN:-11015\n"))


