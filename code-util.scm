;;; Copyright 2018 by Christian Jaeger <ch@christianjaeger.ch>

;;;    This file is free software; you can redistribute it and/or modify
;;;    it under the terms of the GNU General Public License (GPL) as published 
;;;    by the Free Software Foundation, either version 2 of the License, or
;;;    (at your option) any later version.


(require (cj-symbol with-gensym with-gensyms)
	 (list-util-1 map/iota)
	 test
	 (cj-symbol syntax-equal?))

(export early-bind-expressions)


;; Avoid macro's late binding: evaluate used expressions only
;; once. But only if they are not just symbols: leave symbol
;; references late-bound. This can allow to resolve mutual definitions
;; without an extra function wrapper, and can avoid the need for
;; allocating closures.

(define (early-bind-expressions:expr+ expr)
  (list
   ;; what variable name the end code should use to hold the result of
   ;; the evaluation of expr, if any:
   (if (symbol? (source-code expr))
       #f
       (gensym))
   ;; the expression the end code should use (which is just the
   ;; original expression of course):
   expr))

(define (early-bind-expressions:expr+s . exprs)
  (map early-bind-expressions:expr+ exprs))

(define (early-bind-expressions:expr+s-ref-expr* expr+s i)
  (let ((expr+ (list-ref expr+s i)))
    ;; if a symbol was created, use it, otherwise the original
    ;; var-expr name
    (or (car expr+)
	(cadr expr+))))

(define (early-bind-expressions:wrap expr+s code)
  ;; Build code to evaluate the expressions used by the end code that
  ;; need evaluation. This is simply those expr+ which have a
  ;; generated symbol name.
  (let ((need-eval (filter car expr+s)))
    (if (null? need-eval)
	code
	`(##let ,need-eval ,code))))


;; codegen-expr is generating code that is being wrapped to early-bind
;; the variables (which are supposedly used in codegen-expr) that are
;; listed in var-of-exprs:

(define-macro* (early-bind-expressions var-of-exprs codegen-expr)
  (with-gensyms
   (EXPR+S)
   ;; XX source location handling bug somewhere, workaround:
   (cj-desourcify
    `(let ((,EXPR+S (early-bind-expressions:expr+s ,@var-of-exprs)))
       (early-bind-expressions:wrap
	,EXPR+S
	;; re-bind var-of-exprs in the macro expander to the gensyms
	;; or their original, depending on whether they are bound to
	;; an expression or a symbol:
	(let ,(map/iota
	       (lambda (var-of-expr i)
		 `(,var-of-expr
		   (early-bind-expressions:expr+s-ref-expr* ,EXPR+S ,i)))
	       (source-code var-of-exprs))
	  ,codegen-expr))))))

(TEST
 > (define TEST:equal? syntax-equal?)

 > (expansion#early-bind-expressions
    (t1? t2?)
    `(lambda (v)
       (and (pair? v)
	    (,t1? (car v))
	    (,t2? (cdr v)))))
 (let ((GEN:EXPR+S-2454 (early-bind-expressions:expr+s t1? t2?)))
   (early-bind-expressions:wrap
    GEN:EXPR+S-2454
    (let ((t1? (early-bind-expressions:expr+s-ref-expr* GEN:EXPR+S-2454 0))
	  (t2? (early-bind-expressions:expr+s-ref-expr* GEN:EXPR+S-2454 1)))
      `(lambda (v) (and (pair? v) (,t1? (car v)) (,t2? (cdr v)))))))

 > (let ((t1? 'number?) (t2? 'string?))
     (let ((GEN:EXPR+S-2454 (early-bind-expressions:expr+s t1? t2?)))
       (early-bind-expressions:wrap
	GEN:EXPR+S-2454
	(let ((t1? (early-bind-expressions:expr+s-ref-expr* GEN:EXPR+S-2454 0))
	      (t2? (early-bind-expressions:expr+s-ref-expr* GEN:EXPR+S-2454 1)))
	  `(lambda (v) (and (pair? v) (,t1? (car v)) (,t2? (cdr v))))))))
 (lambda (v) (and (pair? v) (number? (car v)) (string? (cdr v))))

 > (eval `(let ((t1? 'number?) (t2? 'string?))
	    ,(expansion#early-bind-expressions
	      (t1? t2?)
	      `(lambda (v)
		 (and (pair? v)
		      (,t1? (car v))
		      (,t2? (cdr v)))))))
 (lambda (v) (and (pair? v) (number? (car v)) (string? (cdr v))))

 > (let ((t1? 'number?) (t2? 'string?))
     (early-bind-expressions
      (t1? t2?)
      `(lambda (v)
	 (and (pair? v)
	      (,t1? (car v))
	      (,t2? (cdr v))))))
 (lambda (v) (and (pair? v) (number? (car v)) (string? (cdr v))))
 
 ;; ^^  kill that sh

 > (define-macro* (my-pair-of t1? t2?)
     (early-bind-expressions
      (t1? t2?)
      `(lambda (v)
 	 (and (pair? v)
 	      (,t1? (car v))
 	      (,t2? (cdr v))))))

 > (expansion#my-pair-of a? b?)
 (lambda (v) (and (pair? v)
 	     (a? (car v))
 	     (b? (cdr v))))
 > (expansion#my-pair-of (maybe a?) b?)
 (##let ((GEN:-2449 (maybe a?)))
 	(lambda (v)
 	  (and (pair? v)
 	       (GEN:-2449 (car v))
 	       (b? (cdr v)))))
 )


