;;; Copyright 2016-2018 by Christian Jaeger <ch@christianjaeger.ch>

;;;    This file is free software; you can redistribute it and/or modify
;;;    it under the terms of the GNU General Public License (GPL) as published 
;;;    by the Free Software Foundation, either version 2 of the License, or
;;;    (at your option) any later version.


(require easy-1
	 joo
	 (joo expand-forms-in-exprs)
	 test)

(include "cj-standarddeclares.scm")


;; more-oo-inspired syntax on top of joo


;; (jinterface name . forms) and (jclass name . forms)

;; where forms are modded directly? No, still use define-syntax, so,
;; the toplevel jinterface / jclass definitions don't inherit, the
;; local redefinitions of those macros do.

;; Ah uh eh, can't use ##define-syntax as it escapes (begin )
;; forms. And I have to use begin forms since non-macro definitions
;; *do* have to escape it. Gah. Back to parsing myself. Forever.

;; So there are still two implementations of the jinterface and jclass
;; forms: the outmost, and the inner ones. Should they be called
;; differently even? Can't really do that right, forgetting etc. (A
;; whole language? Well yes but triggered still and so whole language
;; parser hence forever.)

;; Both implementations do the same thing though, they walk the direct
;; inner layer of forms and run the same expander (recursively) on
;; found forms.


(def (jclass:expand
      interface-syms
      class-syms
      stx
      is-class?
      args
      maybe-super-name
      super-is-class?)
     (let-pair
      ((decl forms) args)
      (let ((c (lambda (_constructor-stx name _maybe-constructor-name _field-decls)
		 `(,(if is-class? `joo-class `joo-interface)
		   ,decl
		   ,@(if maybe-super-name
			 (list (joo-extends-or-implements
				stx super-is-class? is-class?)
			       maybe-super-name)
			 '())
		   ,@(map (C jclass:perhaps-expand-in-context
			     interface-syms
			     class-syms
			     #f
			     _
			     name
			     is-class?)
			  forms)))))
	(joo:parse-decl decl
			cont-renamedconstructor: c
			cont-samename: c
			cont-nofields: c))))


(def (jclass:perhaps-expand-in-context
      ;; the symbols used for interface and class definition forms
      ;; (necessary for nested scopes, as those are parsed directly,
      ;; not via macro system; NOTE: need to include expansion#
      ;; variants, too!):
      interface-syms
      class-syms
      ;; other arguments:
      require-match?
      expr
      maybe-super-name
      super-is-class?)

     ;; XX should use expand-forms-in-exprs from joo.scm to get more
     ;; proper macro treatment
     (mcase expr
	    (pair?
	     (let-pair ((a r) (source-code expr))
		       (if (pair? r)
			   (let ((a* (source-code a)))
			     (if (symbol? a*)
				 (cond ((memq a* interface-syms)
					(jclass:expand interface-syms
						       class-syms
						       expr
						       #f r
						       maybe-super-name
						       super-is-class?))
				       ((memq a* class-syms)
					(jclass:expand interface-syms
						       class-syms
						       expr
						       #t r
						       maybe-super-name
						       super-is-class?))
				       (else expr))
				 expr))
			   (source-error expr "missing decl"))))
	    (else
	     (if require-match?
		 (source-error expr "BUG")
		 expr))))

(defmacro (jinterface decl . forms)
  (jclass:perhaps-expand-in-context '(jinterface expansion#jinterface)
				    '(jclass expansion#jclass)
				    #t stx #f #f))

(defmacro (jclass decl . forms)
  (jclass:perhaps-expand-in-context '(jinterface expansion#jinterface)
				    '(jclass expansion#jclass)
				    #t stx #f #t))

;; ^ XX btw double extends: or implements: keywords, how to handle?
;; Really \SCHEME[keyword arguments should handle duplicate argument
;; case generally]?


(TEST
 > (jinterface jct
	       (jclass (jclass_foo x y)
		       (jclass (bar z)
			       (jclass (baz)))
		       ;; method *after* an inner class definition to
		       ;; test for the ##define-syntax (inner syntax
		       ;; scoping) issue:
		       (def-method- (meth s)
			 (+ (.x s) (.y s))))
	       (jinterface jct2
			   (jclass (jclass_foo2 x))))
 > (jclass_foo 10 12)
 #((jclass_foo) 10 12)
 > (def b (baz 10 12 13))
 > b
 #((baz) 10 12 13)
 > (jclass_foo? b)
 #t
 > (jct? b)
 #t
 > (jct2? b)
 #f
 > (jct? (jclass_foo2 1))
 #t
 > (jct2? (jclass_foo2 1))
 #t
 ;; > (jct? jct2) ehr there's no constructor. Do or do I not
 ;; have a way to check this hierarchy just on the class level yet?

 > (with-exception-catcher
    source-error-message
    (& (eval (quote-source (jinterface jct
 				       (jclass (foo x y)
 					       (jinterface jctdeep
 							   (jclass (bar z)
 								   (jclass (baz)))))
 				       (jinterface jct2
 						   (jclass (foo2 x))))))))
 "an interface cannot extend a class"

 ;; Test the inner syntax scoping thing:
 > (expansion#jclass (foo x y) (jclass (bar z)))
 (joo-class (foo x y)
	    (joo-class (bar z) extends: foo))
 > (expansion#jclass (foo x y)
		     (jclass (bar z) (def-method- (meth s) 'bar))
		     (def-method- (meth s) 'foo))
 (joo-class
  (foo x y)
  (joo-class (bar z) extends: foo (def-method- (meth s) 'bar))
  (def-method- (meth s) 'foo))

 ;; and on the earlier, actually executed, definition of foo:
 > (.meth (jclass_foo 10 11))
 21)


;; Scoping: do not re-arrange stuff
(TEST
 > (jclass two
	   (jclass (two1 x))
	   ;; Yes, the scope of two being able to access syntactical
	   ;; definitions in two1 is kinda weird, but well? It would
	   ;; be odd if it would only work as |def.| after exiting the
	   ;; two's scope.
	   (def (t-two1 s)
		(let-two1 ((x) s)
			  x)))
 > (t-two1 (two1 12))
 12)

