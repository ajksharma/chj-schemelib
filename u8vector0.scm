;;; Copyright 2016 by Christian Jaeger <chrjae@gmail.com>

;;;    This file is free software; you can redistribute it and/or modify
;;;    it under the terms of the GNU General Public License (GPL) as published 
;;;    by the Free Software Foundation, either version 2 of the License, or
;;;    (at your option) any later version.


;; A representation of char* buffers using Scheme objects. NOTE: does
;; not use a separate type name! (Todo: write a separate cstring.scm
;; as such a wrapper?)

;; Also see u8-parse.scm, cj-u8vector-util.scm (Todo: clean up?)


(require test
	 easy
	 (cj-source-util-2 assert)
	 utf8 ;; or include? sigh.
	 unclean
	 (string-util-3 list.string-reverse))

(c-declare "
       #include <string.h>
       #include <assert.h>
")


(def (u8vector0? v)
     (and (u8vector? v)
	  (let ((len (u8vector-length v)))
	    (and (>= len 1)
		 (zero? (u8vector-ref v (dec len)))))))

(TEST
 > (u8vector0? (u8vector))
 #f
 > (u8vector0? (u8vector 0))
 #t
 > (u8vector0? (u8vector 1 0))
 #t
 > (u8vector0? (u8vector 0 1))
 #f)


;; Call this strlen and not length since u8vector0.length and
;; u8vector.length would be dangerously ambiguous (a 0 value at the
;; end would make length be reported shorter than expected for work
;; with u8vectors that *do* allow 0 values). Also, this doesn't do
;; UTF-8 decoding which might be expected; thus really reuse the libc
;; name.

(def. (u8vector0.strlen v)
  (assert (u8vector0? v)) ;; XX should really be made part of method? !
  (##c-code "
size_t res= strlen(___CAST(char*,___BODY(___ARG1)));
assert(res <= ___MAX_FIX);
___RESULT= ___FIX(res);
" v))

(TEST
 > (%try-error (u8vector0.strlen (u8vector)))
 #(error "assertment failure: (u8vector0? v)" (u8vector0? '#u8()))
 > (%try-error (u8vector0.strlen (u8vector 100)))
 #(error "assertment failure: (u8vector0? v)" (u8vector0? '#u8(100)))
 > (u8vector0.strlen (u8vector 100 0))
 1
 > (u8vector0.strlen (u8vector 100 99 98 0))
 3
 > (u8vector0.strlen (u8vector 100 99 98 0 3 4 5 0))
 3
 > (.strlen '#u8(195 164 195 182 195 188 0))
 6 ;; whereas those are just 3 characters
 )



;; format as UTF-8

;;(include "utf8.scm") now loaded as normal dependency

(def. (string.utf8-bytes s #!optional (len (string-length s)))
  (let lp ((i 0)
	   (l 0))
    (if (< i len)
	(lp (inc i)
	    (+ l (utf8-bytes (char->integer (string-ref s i)))))
	l)))


;; Also see string->u8vector0 in cj-u8vector-util.scm which can't do
;; UTF-8; XX eliminate it.

(def. (string.utf8-u8vector0 s)
  (let* ((len (string-length s))
	 (bytes (string.utf8-bytes s len))
	 (out (##make-u8vector (inc bytes))))
    (let lp ((i 0)
	     (i* 0))
      (if (< i len)
	  (lp (inc i)
	      (u8vector.utf8-put! out i*
				  ;; don't accept 0 byte, ok?
				  (-> positive?
				      (char->integer (string-ref s i)))))
	  (begin
	    (u8vector-set! out bytes 0)
	    out)))))

(TEST
 > (string.utf8-u8vector0 "Hello")
 #u8(72 101 108 108 111 0)
 > (string.utf8-u8vector0 "Hellö")
 #u8(72 101 108 108 195 182 0)
 > (string.utf8-u8vector0 "Hellöl")
 #u8(72 101 108 108 195 182 108 0)
 > (string.utf8-u8vector0 "äöü")
 ;; #u8(#xC3 #xA4  #xC3 #xB6  #xC3 #xBC  0) =
 #u8(195 164 195 182 195 188 0)
 
 ;; > (string.utf8-u8vector0 "Hel\0lo")
 ;; #u8(72 101 108 0 108 111 0)
 ;; That would be bad, thus now:
 > (%try-error (string.utf8-u8vector0 "Hel\0lo"))
 ;; XX better error message?
 #(error "value fails to meet predicate:" (positive? 0)))


(def. (u8vector0.string #(u8vector0? v))
  (let ((len (u8vector0.strlen v)))
    (let lp ((i 0)
	     ;; using a list instead of pre-calculating size, XX room
	     ;; for optimization (also use @u8vector.utf8-get then).
	     (l '())
	     (n 0))
      (if (< i len)
	  (letv ((maybe-c i*) (u8vector.utf8-get v i))
		(if maybe-c
		    (lp i*
			(cons maybe-c l)
			(inc n))
		    (if (= i* i)
			(error "utf-8 decoding error, can't proceed")
			;; otherwise just skip it, OK?
			(begin
			  (warn "utf-8 decoding error, skipping over bad sequence")
			  ;; XX or should we die anyway?
			  (lp i* l n)))))
	  (list.string-reverse l)))))

(TEST
 > (.string '#u8(195 164 195 182 195 188 0))
 "äöü"
 > (.string '#u8(195 164 195 182 195 188 0 0))
 "äöü"
 > (%try-error (u8vector0.string '#u8(195 164 195 182 195 0 188 0)))
 #(error "utf-8 decoding error, can't proceed")
 > (.string '#u8(195 164 195 182 0 195 188 0))
 "äö"
 > (%try-error (u8vector0.string '#u8(195 164 195 0 182 195 188 0)))
 #(error "utf-8 decoding error, can't proceed"))
