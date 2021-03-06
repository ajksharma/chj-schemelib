;;; Copyright 2010, 2011 by Christian Jaeger <ch@christianjaeger.ch>

;;;    This file is free software; you can redistribute it and/or modify
;;;    it under the terms of the GNU General Public License (GPL) as published 
;;;    by the Free Software Foundation, either version 2 of the License, or
;;;    (at your option) any later version.


(require define-macro-star
	 simple-match-1)

(export (macro define-inline.1))

;; looses location information; see cj-inline for a version that uses
;; quasiquote-source. Now using a different name, to prevent
;; re-compilations after loading cj-inline from expanding to code that
;; depends on cj-inline instead of cj-inline-1.

(define-macro* (define-inline.1 name+vars body0 . body)
  (match-list*
   name+vars
   ((name . vars)
    (let ((templatecode
	   `((lambda ,vars
	       ,body0 ,@body)
	     ,@(map (lambda (v)
		      (list 'unquote v)) vars))))
      (list 'define-macro* name+vars
	    (list 'quasiquote templatecode))))))

