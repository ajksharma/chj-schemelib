;;; Copyright 2010, 2011 by Christian Jaeger <chrjae@gmail.com>

;;;    This file is free software; you can redistribute it and/or modify
;;;    it under the terms of the GNU General Public License (GPL) as published 
;;;    by the Free Software Foundation, either version 2 of the License, or
;;;    (at your option) any later version.


(require (lib.define-macro-star)
	 (lib.cj-phasing)
	 (lib.test)
	 (lib.simple-match)
	 (lib.srfi-11))


;;;
;;;; runtime-parameterized modules
;;;

;; define-macro* is supported, both for making and use of definitions;
;; module parameters are runtime only (macro expander code can't
;; access them)

;; XXX does not handle lexical scope, e.g. macro bindings are never
;; shadowed, neither is other syntax, like in (let ((let 'a)) let)
;; which should return a


(both-times ;; runtime mostly just for the tests

 (define (convert-module-body forms bodytail)
   (define local-expanders '())
   (parameterize
    ((define-macro*-maybe-local-callback
       (lambda (name expander)
	 (push! local-expanders (cons name expander)))))
    (letv
     ;; use left fold then reverse so that the order of the side
     ;; effects done by the macro expanders is correct
     ((revmovedout revconvertedforms)
	   (fold
	    (named
	     redo
	     (lambda (form movedout+res)
	       (let* ((return
		       (lambda (val)
			 (letv ((movedout res) movedout+res)
			       (values movedout
				       (cons val res)))))
		      (redo-with
		       (lambda (val)
			 (redo val movedout+res)))
		      (return-non-define
		       (lambda ()
			 (return (list (gensym)
				       form))))
		      (move-out
		       (lambda (val)
			 (letv ((movedout res) movedout+res)
			       (values (cons val movedout)
				       res)))))
		 (let ((form* (source-code form)))
		   (if (pair? form*)
		       (let-pair
			((head rest1) form*)
			(let ((head* (source-code head)))
			  (if (symbol? head*)
			      (case head*
				((define)
				 (match* ;; is a define never a dotted list? XX
				  form
				  ((define bind . rest2)
				   (let ((bind* (source-code bind)))
				     (cond ((pair? bind*)
					    (let-pair
					     ((name vars) bind*)
					     (return (list name
							   `(lambda ,vars
							      ,@rest2)))))
					   ((symbol? bind*)
					    (return rest1))
					   (else
					    (source-error
					     bind
					     "expecting pair or symbol")))))))
				((begin)
				 ;; flatten into the outer list
				 (fold redo
				       movedout+res
				       rest1))
				((##define-syntax)
				 (move-out form))
				(else
				 (cond ((or (cond ((assq head* local-expanders)
						   => cdr)
						  (else #f))
					    (define-macro-star-maybe-ref head*))
					=> (lambda (expand)
					     ;;(warn "found expander for" head*)
					     (redo-with (expand form))))
				       (else
					(return-non-define)))))
			      (return-non-define))))
		       (return-non-define))))))
	    (values '() '())
	    forms))
	  (let ((convertedforms (reverse revconvertedforms))
		(movedout (reverse revmovedout)))
	    (if (mod:compiled?)
		`(begin
		   ,@movedout
		   (letrec ,convertedforms
		     ,@bodytail))
		`(let ,(map (lambda (var+expr)
			      (match* var+expr
				      ((var expr)
				       `(,var 'define-module-unbound))))
			    (filter (compose* not cj-gensym? car)
				    convertedforms))
		   ,@movedout
		   ,@(map (lambda (var+expr)
			    (match* var+expr
				    ((var expr)
				     (if (cj-gensym? var)
					 expr
					 `(set! ,var ,expr)))))
			  convertedforms)
		   ,@bodytail)))))))


(TEST
 > (require (lib.cj-symbol)))
(TEST
 > (define TEST:equal? syntax-equal?)
 > (define (conv forms body)
     (vector
      (convert-module-body forms body)
      (parameterize
       ((mod:compiled? #t))
       (convert-module-body forms body))))
 > (conv '((define a 1) (define b (a 2))) '(mybody))
 #((let ((a 'define-module-unbound) (b 'define-module-unbound))
     (set! a 1)
     (set! b (a 2))
     mybody)
   (begin (letrec ((a 1) (b (a 2))) mybody)))
 > (conv '((define a 1) (set! a list) (define b (a 2))) '(b))
 #((let ((a 'define-module-unbound) (b 'define-module-unbound))
     (set! a 1) (set! a list) (set! b (a 2))
     b)
   (begin (letrec ((a 1) (GEN:3716 (set! a list)) (b (a 2))) b)))
 > (eval (vector-ref # 0))
 (2)
 ;; macro expansion test see further below (expansion too big to use here)
 )


(define-macro* (define-module name-or-name+params export-form . body)
  (assert* (either pair? symbol?) name-or-name+params
	   (lambda (name-or-name+params*)
	     ((lambda (name)
		(match*
		 export-form
		 ((_export . exports)
		  (if (eq? (source-code _export) 'export)
		      (with-gensyms
		       (VARNAME)
		       (let ((exports-name (symbol-append name '-exports)))
			 `(begin
			    (define ,exports-name
			      ',exports)
			    (define ,name-or-name+params
			      ,(convert-module-body
				body
				`((lambda (,VARNAME)
				    (if ,VARNAME
					(case ,VARNAME
					  ,@(map/tail
					     (lambda_
					      `((,_) ,_))
					     `((else
						(error
						 "in module, name not exported:"
						 ',name
						 ,VARNAME)))
					     (source-code exports)))
					,exports-name))))))))
		      (source-error
		       export-form
		       "expecting (export . VAR*) form")))))
	      (if (pair? name-or-name+params*)
		  (car name-or-name+params*)
		  name-or-name+params*)))))

(TEST
 > (define-module (foo x) (export f) (define (f n) (/ n x)))
 > (((foo 10) 'f) 5)
 1/2
 > ((foo 10) #f)
 (f)
 )


(define-macro* (module:import expr . vars)
  (let ((mk (lambda (select)
	      (lambda_
	       (if (symbol? (source-code _))
		   _
		   (match-list* _
				((to from) (select from to))))))))
    (let ((from (mk (lambda (from to) from)))
	  (to (mk (lambda (from to) to))))
      
      (if (pair? vars)
	  (with-gensyms
	   (M)
	   `(begin
	      ,@(map (lambda_
		      `(define ,(to _) #f))
		     vars)
	      (let ((,M ,expr))
		,@(map (lambda_
			;; (rather inefficient, allocates closures for all of
			;; the function variables)
			`(set! ,(to _) (,M ',(from _))))
		       vars))))
	  (source-error
	   stx
	   "expecting a list of variables to import after the first argument")))))

(TEST
 > (module:import (foo 11) f)
 > (f 4)
 4/11

 ;; macro test
 > (define-module (tmod)
     (export f expander#tmac)
     (define-macro* (tmac x)
       (list 'quote x))
     (define (f . a)
       (cons (tmac foo) a)))
 > (module:import (tmod) f)
 > (f 1 2)
 (foo 1 2)
 ;; > tmac
 ;; *** ERROR IN (console)@17.1 -- Macro name can't be used as a variable: tmac
 ;; hmm hu
 > (define-macro-star-maybe-ref 'tmac)
 #f
 ;; > expander#tmac
 ;; *** ERROR IN (console)@3.1 -- Unbound variable: expander#tmac
 > (module:import (tmod) expander#tmac)
 > (procedure? expander#tmac)
 #t

 ;; more macro testing: (use leading to def and then use the latter too)
 > (define-module (tmod2 x)
     (export b make-foo foo incfoobar)
     (define a 1)     
     (define-struct foo bar)
     (set! a list)
     (define b (a x))
     (define foo make-foo)
     (define (incfoobar x)
       (let-foo ((b) x)
		(inc b))))
 > (module:import (tmod2 'A) foo make-foo incfoobar b)
 > b
 (A)
 > (eq? foo make-foo)
 #t
 > (incfoobar (make-foo 10))
 11

 ;; renaming
 > (module:import (tmod2 'A2) (bbb b))
 > bbb
 (A2)
 )


(define (module:parse-prefix prefix cont)
  (let ((prefix* (source-code prefix)))
    (cond ((symbol? prefix*)
	   (cont prefix*))
	  ((keyword? prefix*)
	   (cont (symbol-append (keyword->string prefix*) ":")))
	  (else
	   (source-error prefix "expecting string or symbol")))))

(define-macro* (module:import/prefix expr prefix . vars)
  (if (null? vars)
      (source-error ctx "missing bindings to import")
      (module:parse-prefix
       prefix
       (lambda (prefix)
	 `(module:import
	   ,expr
	   ,@(map (lambda (var)
		    (assert* symbol? var
			     (lambda (var)
			       `(,(symbol-append prefix var) ,var))))
		  vars))))))

(TEST
 > (define-module (foo x) (export a b c) (define a 4))
 > (module:import/prefix (foo 4) foo: a b)
 > foo:a
 4
 )


;; *Can't* write a |module:import-all/prefix| because the module
;; initialization expression is evaluated at runtime (thus it's not
;; even known what module it will be). Those are runtime modules
;; really, after all...

;; But can write a macro that builds up the initialization expression
;; itself:

(define-macro* (module-import prefix name . args)
  (assert* symbol? name
	   (lambda (name)
	     `(module:import/prefix (,name ,@args)
				    ,prefix
				    ,@(eval (symbol-append name '-exports))))))

(TEST
 > (compile-time ;; necessary since TEST evaluates all subtests in one go
    (define-module (foo x) (export a b)
      (define a 4)
      (define b (* x a))))
 > (module-import foo5: foo 5)
 > foo5:a
 4
 > foo5:b
 20
 )

