;;; Copyright 2016-2018 by Christian Jaeger <ch@christianjaeger.ch>

;;;    This file is free software; you can redistribute it and/or modify
;;;    it under the terms of the GNU General Public License (GPL) as published 
;;;    by the Free Software Foundation, either version 2 of the License, or
;;;    (at your option) any later version.


(require dot-oo
	 cj-struct
	 (cj-source-util-2 assert)
	 (scheme-meta self-quoting)
	 (cj-gambit-sys procedure-name)
	 (srfi-11 values? values->list)
	 ;; dot-oo depends on cj-env already, and we want to add on/registry.show :
	 (cj-env on/registry? on/registry-ref)
	 debuggable-promise
	 ;; ^ now we have to always load it. But, have
	 ;; debuggable-promise-everywhere now which is optional.
	 (lazy-debug S)
	 cj-source
	 test)


(export (method .show)
	(method .show-string)
	try-show
	#!optional
	toplevel-procedure?
	struct-values)

(include "cj-standarddeclares.scm")


(define. (self-quoting.show v)
  v)

(define. (symbol.show v)
  `(quote ,v))


;; XX if not struct. ugly implicit assumption through ordering
;; currently. More generic must be earlier.

(define. (vector.show v)
  `(vector ,@(map .show (vector->list v))))

(define. (pair.show v)
  `(cons ,(.show (car v))
	 ,(.show (cdr v))))

(define. (list.show v)
  (cons 'list (map .show v)))


(define. (values.show v)
  (cons 'values (map .show (values->list v))))

(define. (box.show v)
  `(box ,(.show (unbox v))))

;; good or bad idea?
(define. (void.show v)
  `(void))


;; XX should rename original ones instead? anyway, move to cj-source.scm
;; (define source make-source)
;; (define location make-location)
;; (define position make-position)
;; (define position* make-position*)
;; or actually use a different constructor than make-source, given its flat representation.

;;(define source:tag '[source1]) sigh, don't have it

(define (source code
		;; location
		location-container
		location-line&column)
  (make-source code (make-location location-container
				   location-line&column)))

(define (@source-location-container s)
  (vector-ref s 2))
(define (@source-location-line&column s)
  (vector-ref s 3))
;; /move

(define. (source.show v)
  `(source ,(.show (source-code v))
	   ,(@source-location-container v)
	   ,(@source-location-line&column v)))


;; XX move? to predicates or rather cj-gambit-sys?
(define (toplevel-procedure? v)
  (and (procedure? v)
       (maybe-procedure-name v)
       #t))

(define. toplevel-procedure.show maybe-procedure-name)

;; structs:

;; XXX HACK for now, should generate for each struct according to its
;; (default) constructor:

(define. (struct.show v)
   ;; The HACK is: assumption that the constructor takes positional
   ;; arguments
  (cons (struct-constructor-name v)
	(map .show (struct-values v))))



(TEST
 > (.show '(1 2 3))
 (list 1 2 3)
 > (.show '(1 2 . 3))
 (cons 1 (cons 2 3))
 > (.show (values (+ 1 2) 2))
 (values 3 2))



(define (try-show v)
  (with-exception-catcher
   (lambda (e)
     `(try-show ,v))
   (lambda ()
     (.show v))))

;; (def. (exception.show e)
;;   `(raise ,e))
;; oh {##,}exception? doesn't exist

(define. (error-exception.show e)
  `(error ,(error-exception-message e)
	  ;; used to map try-show over it, but, even though correct,
	  ;; it is ugly, since error arguments (usually?) are already
	  ;; show'n "or so" (still have to examine correctly). Thus
	  ;; just quote, OK?
	  ,@(map (lambda_ `',_) (error-exception-parameters e))))

(define. (unbound-global-exception.show e)
  ;;`(unbound-global-exception )  hmm or really simply?:
  `(unbound-global-exception ',(unbound-global-exception-variable e)))

(define (unbound-global-exception var)
  (error "(XX unbound-global-exception not implemented)" var))


(define. (u8vector.show v)
  `(u8vector ,@(u8vector->list v)))

(define. (on/registry.show v)
  (let* ((p (on/registry-ref v))
	 (access (car p))
	 (cmp (cdr p)))
    `(on/registry ,(.show access)
		  ,(.show cmp))))



(define (promise# n)
  (let ((v (serial-number->object n)))
    (if (promise? v)
	v
	(error "not a promise:" n))))

(define. (debuggable-promise.show v)
  (if (debuggable-promise? v)
      (if (@debuggable-promise-evaluated? v)
	  ;; pre-force all the way before calling .show again (so that
	  ;; things like list? will match, although this may trigger
	  ;; n^2 complexity issues more easily? XX)
	  (.show (S v))
	  `(promise# ,(object->serial-number v)))
      ;; shouldn't happen 'usually' (ever this question, unsafe direct call)
      (error "not a debuggable-promise:" v)))

(define. (##promise.show v)
  (if (##promise? v)
      (if (@promise-evaluated? v)
	  (.show (S v))
	  `(promise# ,(object->serial-number v)))
      ;; shouldn't happen 'usually' (ever this question, unsafe direct call)
      (error "not a ##promise:" v)))


(define. (any.show-string v)
  (object->string (.show v)))

