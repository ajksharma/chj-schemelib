;;; Copyright 2010, 2011 by Christian Jaeger <ch@christianjaeger.ch>

;;;    This file is free software; you can redistribute it and/or modify
;;;    it under the terms of the GNU General Public License (GPL) as published 
;;;    by the Free Software Foundation, either version 2 of the License, or
;;;    (at your option) any later version.


(require lazy
	 debuggable-promise)

(export F
	F1
	F*)


(possibly-use-debuggable-promise)

;; make copy forcing everything
(define (F s)
  (let F ((s s))
    (let ((s* (force s)))
      (if (eq? s* s)
	  s
	  (if (pair? s*)
	      (cons (F (car s*))
		    (F (cdr s*)))
	      s*)))))

;; make copy forcing everything, but show <P> wherever there was a
;; promise (and one level at that for each). XX force1 is not
;; consistently implemented now.
(define (F1 s)
  (let F ((s s))
    (cond ((promise? s)
	   (vector '<P>
		   (let ((s (force1 s)))
		     (F s))))
	  ((pair? s)
	   (cons (F (car s))
		 (F (cdr s))))
	  (else
	   s))))

;; only copy what was already evaluated
(define (F* s)
  (let F ((s s))
    (if (promise? s)
	(if (promise-evaluated? s)
	    (let ((s* (evaluated-promise-value s)))
	      (if (eq? s* s)
		  s
		  (if (pair? s*)
		      (cons (F (car s*))
			    (F (cdr s*)))
		      s*)))
	    s)
	s)))

