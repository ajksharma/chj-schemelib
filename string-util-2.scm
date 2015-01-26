;;; Copyright 2013-2014 by Christian Jaeger <chrjae@gmail.com>

;;;    This file is free software; you can redistribute it and/or modify
;;;    it under the terms of the GNU General Public License (GPL) as published 
;;;    by the Free Software Foundation, either version 2 of the License, or
;;;    (at your option) any later version.


(define (suffix-list l)
  (rxtake-while (lambda (x)
                 (not (char=? x #\.)))
               (reverse l)))

(define suffix (compose* list->string suffix-list string->list))

(TEST
 > (suffix "foo.scm")
 "scm"
 )

(define (list-dropstop stop? fail? stop fail)
  (named self
	 (lambda (l)
	   (if (null? l)
	       (fail l)
	       (let-pair ((a r) l)
			 (cond ((fail? a)
				(fail r))
			       ((stop? a)
				(stop r))
			       (else
				(self r))))))))

(TEST
 > (define t-list-dropstop
     (compose
      (list-dropstop (lambda (v) (eq? v #\.))
		     (lambda (v) (eq? v #\/))
		     (lambda (v) (vector 'stop (list->string v)))
		     (lambda (v) (vector 'fail (list->string v))))
      string->list))
 > (t-list-dropstop "foo.bar/baz")
 #(stop "bar/baz")
 > (t-list-dropstop "foobar/baz")
 #(fail "baz")
 > (t-list-dropstop "foobarbaz")
 #(fail ""))

(define (strip-suffix str)
  ((list-dropstop (lambda (v) (eq? v #\.))
		  (lambda (v) (eq? v #\/))
		  (lambda (v) (list->string (reverse v)))
		  (lambda (v) str))
   (reverse (string->list str))))

(TEST
 > (strip-suffix "/foo.scm")
 "/foo"
 > (strip-suffix "/foo")
 "/foo"
 > (strip-suffix "/foo.")
 "/foo"
 > (strip-suffix "bar.d/foo")
 "bar.d/foo"
 > (strip-suffix "bar.d/foo.sf.scm")
 "bar.d/foo.sf")


;; slow way. just  .
;; drop-while but from the end.
(define (list-trim-right lis pred)
  ((compose* reverse
	     (cut drop-while pred <>)
	     reverse) lis))


(define string-trim-right
  (compose* list->string
	    (cut list-trim-right <> char-whitespace?)
	    string->list))

(TEST
 > (string-trim-right "")
 ""
 > (string-trim-right " ")
 ""
 > (string-trim-right "foo\n")
 "foo"
 > (string-trim-right "foo\n ")
 "foo"
 )


(define (string-ref* str i)
  (if (negative? i)
      (let ((len (string-length str)))
	(string-ref str (+ len i)))
      (string-ref str i)))
(TEST
 > (string-ref* "abc" 0)
 #\a
 > (string-ref* "abc" 1)
 #\b
 > (string-ref* "abc" -1)
 #\c
 > (string-ref* "abc" -2)
 #\b
 > (with-exception-handler range-exception? (thunk (string-ref* "abc" -4)))
 #t
 )

(define (string-empty? str)
  (zero? (string-length str)))

;; A string chom that works like Perl's

(define (chomp str)
  (if (string-empty? str)
      str
      (if (char=? (string-ref* str -1) #\newline) ;; Perl even ignores \r heh
	  (substring str 0 (dec (string-length str)))
	  str)))

(TEST
 > (chomp "")
 ""
 > (chomp " ")
 " "
 > (chomp "a\n")
 "a"
 > (chomp "a\n\n")
 "a\n"
 > (chomp "a\r")
 "a\r"
 )

;; ok?
(define trim string-trim-right)

(define trim-maybe (_-maybe trim))

(define char-newline?
  (cut char=? <> #\newline))

(define trimlines
  (compose* (cut strings-join <> "\n")
	    (cut map trim <>)
	    (cut string-split <> char-newline?)))

(define trimlines-maybe (_-maybe trimlines))

(TEST
 > (trimlines " Hello \nWorld. \n")
 " Hello\nWorld.\n"
 > (trimlines " Hello \nWorld.\n")
 " Hello\nWorld.\n"
 > (trimlines " Hello \nWorld.\n ")
 " Hello\nWorld.\n"
 )


;; hm stupid, basically same thing. With (back to) full names, which
;; is good, and trimming the end too, which may be good too.
(define (string-trimlines-right str)
  (strings-join (map string-trim-right
		     (string-split (string-trim-right str)
				   #\newline))
		"\n"))

(TEST
 > (string-trimlines-right " ")
 ""
 > (string-trimlines-right "")
 ""
 > (string-trimlines-right "foo \nbar ")
 "foo\nbar"
 > (string-trimlines-right "foo \nbar \n \n\n")
 "foo\nbar"
 > (string-trimlines-right "foo \nbar \n \n\nbaz")
 "foo\nbar\n\n\nbaz"
 > (string-trimlines-right " foo \nbar \n \n\nbaz")
 " foo\nbar\n\n\nbaz"
 )



(define (nonempty? v)
  (and v
       (not (string-empty? (trim v)))))

;; bad name? but:
;; - maybe handling
;; - string empty handling
;; - but *also* trimming.
;; Too much for web stuff? dunno

(TEST
 > (nonempty? #f)
 #f
 > (nonempty? "")
 #f
 > (nonempty? " ")
 #f
 > (nonempty? "\n")
 #f
 > (nonempty? "f\n")
 #t
 )


(define (string-multiply str n)
  (let* ((len (string-length str))
	 (out (##make-string (* len n))))
    (for..< (i 0 n)
	    (for..< (j 0 len)
		    (string-set! out
				 (+ (* i len) j)
				 (string-ref str j))))
    out))

(TEST
 > (string-multiply "ab" 3)
 "ababab"
 )

(define-typed (number->padded-string #(natural? width)
				     #(natural0? x))
  (let* ((s (number->string x))
	 (len (string-length s)))
    (string-append (string-multiply "0" (max 0 (- width len)))
		   s)))

(TEST
 > (number->padded-string 3 7)
 "007"
 > (number->padded-string 3 713)
 "713"
 > (number->padded-string 3 7132)
 "7132"
 > (number->padded-string 3 0)
 "000"
 )


;; XX move to some math lib?
(define-typed (inexact.round-at x #(integer? digit-after-comma))
  (let ((factor (expt 10 digit-after-comma)))
    (/ (round (* x factor)) factor)))

(TEST
 > (inexact.round-at 5.456 2)
 5.46
 > (inexact.round-at 5.456 3)
 5.456
 > (inexact.round-at 5.456 1)
 5.5
 > (inexact.round-at 5.456 0)
 5.
 )

(define-typed (inexact.number-format x #(natural0? left) #(natural0? right))
  (let* ((str (number->string (inexact.round-at x right)))
	 (len (string-length str)))
    (if (string-contains? str "e")
	;; XXX how to do better than this, sigh?
	str
	(letv ((before after) (string-split-1 str #\.))
	      ;; after contains the dot, too
	      (let* ((lenbefore (string-length before))
		     (lenafter (string-length after)))
		(string-append (string-multiply " " (max 0 (- left lenbefore)))
			       before
			       after
			       (string-multiply "0" (- right (dec lenafter)))))))))

(TEST
 > (inexact.number-format 3.456 3 3)
 "  3.456"
 > (inexact.number-format 3.456 3 4)
 "  3.4560"
 > (inexact.number-format 3.456 3 2)
 "  3.46"
 > (inexact.number-format 3.456 2 2)
 " 3.46"
 > (inexact.number-format 3.456 1 2)
 "3.46"
 > (inexact.number-format 3.456 0 2)
 "3.46"
 )


(define (string-_-starts? char=?)
  (lambda (str substr)
    (let ((strlen (string-length str))
	  (sublen (string-length substr)))
      (let lp ((stri 0))
	(let sublp ((subi 0))
	  (if (< subi sublen)
	      (let ((stri* (+ stri subi)))
		(if (< stri* strlen)
		    (if (char=? (string-ref str stri*)
				(string-ref substr subi))
			(sublp (inc subi))
			;; the only change versus string-_-contains?:
			#f)
		    ;; (lp (inc stri)) would be same here:
		    #f))
	      #t))))))

(define string-starts? (string-_-starts? char=?))
(define string-starts-ci? (string-_-starts? char-ci=?))

(define (string-_-contains char=? found)
  (lambda (str substr)
    (let ((strlen (string-length str))
	  (sublen (string-length substr)))
      (let lp ((stri 0))
	(let sublp ((subi 0))
	  (if (< subi sublen)
	      (let ((stri* (+ stri subi)))
		(if (< stri* strlen)
		    (if (char=? (string-ref str stri*)
				(string-ref substr subi))
			(sublp (inc subi))
			(lp (inc stri)))
		    #f))
	      (found stri)))))))

;; these return (maybe position)
(define string-contains (string-_-contains char=? identity))
(define string-contains-ci (string-_-contains char-ci=? identity))

;; these return boolean
(define string-contains? (string-_-contains char=? true/1))
(define string-contains-ci? (string-_-contains char-ci=? true/1))

(TEST
 > (define (test a b)
     (list (string-starts? a b)
	   (string-contains? a b)
	   (string-contains a b)))
 > (test "" "")
 (#t #t 0)
 > (test "foo" "")
 (#t #t 0)
 > (test "foo" "bar")
 (#f #f #f)
 > (test "foo" "far")
 (#f #f #f)
 > (test "foo" "fa")
 (#f #f #f)
 > (test "foo" "f")
 (#t #t 0)
 > (test "foo" "for")
 (#f #f #f)
 > (test "foo" "fo")
 (#t #t 0)
 > (test "foo" "foo")
 (#t #t 0)
 > (test "foo" "oo")
 (#f #t 1)
 > (test "foo" "oox")
 (#f #f #f)
 > (test "foo" "foof")
 (#f #f #f)
 > (test "foo" "Oo")
 (#f #f #f)
 > (string-contains-ci? "foo" "Oo")
 #t
 > (string-contains-ci "foo" "Oo")
 1
 > (string-starts? "foo" "Fo")
 #f
 > (string-starts-ci? "foo" "Fo")
 #t
 )


;; 1 like 'only split once'
(define-typed (string-split-1 str
			      #((either char? procedure?) val-or-pred)
			      #!optional drop-match?)
  (let ((len (string-length str))
	(pred (if (procedure? val-or-pred)
		  val-or-pred
		  (lambda (c)
		    (eq? c val-or-pred)))))
    (let lp ((i 0))
      (if (< i len)
	  (if (pred (string-ref str i))
	      (values (substring str 0 i)
		      (substring str (if drop-match?
					 (inc i)
					 i) len))
	      (lp (inc i)))
	  (values str "")))))

;; XX mostly-copy-paste of string-split-1
(define-typed (if-string-split-once
	       str
	       #((either char? procedure?) val-or-pred)
	       #(boolean? drop-match?)
	       #(procedure? then)
	       #(procedure? els))
  (let ((len (string-length str))
	(pred (if (procedure? val-or-pred)
		  val-or-pred
		  (lambda (c)
		    (eq? c val-or-pred)))))
    (let lp ((i 0))
      (if (< i len)
	  (if (pred (string-ref str i))
	      (then (substring str 0 i)
		    (substring str (if drop-match?
				       (inc i)
				       i) len))
	      (lp (inc i)))
	  (els)))))

;; same as string-split-1 but returns false as the second value if
;; there's no match
(define (string-split-once str val-or-pred drop-match?)
  (if-string-split-once str val-or-pred drop-match?
			values
			(C values str #f)))

(TEST
 > (def (t spl failresult)
	(local-TEST
	 > (spl "ab  c d" char-whitespace?)
	 #("ab" "  c d")
	 > (spl "foo?q=1" #\?)
	 #("foo" "?q=1")
	 > (spl "foo?q=1" #\? #t)
	 #("foo" "q=1")
	 > (spl "foo?" #\?)
	 #("foo" "?")
	 > (equal? (spl "foo" #\?) failresult)
	 #t))
 > (%test (t (lambda (str p #!optional ?)
	       (values->vector (string-split-1 str p ?)))
	     '#("foo" "")))
 > (%test (t (lambda (str p #!optional ?)
	       (values->vector (string-split-once str p ?)))
	     '#("foo" #f)))
 > (%test (t (lambda (str p #!optional ?)
	       (if-string-split-once str p ?
				     vector
				     false/0))
	     #f)))


(define string-reverse
  ;;XX bah
  (compose* list->string reverse string->list))

;; dirname that gives empty string for root. yeah, remembering now
(define (dirname* str)
  ;;XX woah super efficiency and anything
  (chain str
	 (string->list)
	 (list-trim-right (cut char=? <> #\/))
	 (reverse)
	 (list->string)
	 (string-split-1 #\/)
	 (snd)
	 (string->list)
	 (reverse)
	 (list-trim-right (cut char=? <> #\/))
	 (list->string)))

(TEST
 > (dirname* "/foo")
 ""
 > (dirname* "/foo/bar")
 "/foo"
 > (dirname* "/foo/bar/")
 "/foo" ;;  XXX should be "/foo/bar" for the web
 > (dirname* "//foo")
 ""
 > (dirname* "//foo//bar")
 "//foo"
 )


;; finally, hu?
(define (string-map fn str)
  (let* ((len (string-length str))
	 (res (##make-string len)))
    (for..< (i 0 len)
	    (string-set! res i (fn (string-ref str i))))
    res))

(define (string-every fn str)
  (let ((len (string-length str)))
    (let lp ((i 0))
      (if (< i len)
	  (if (fn (string-ref str i))
	      (lp (inc i))
	      #f)
	  #t))))

(TEST
 > (string-every (lambda (x) (char=? x #\x)) "")
 #t
 > (string-every (lambda (x) (char=? x #\x)) "x")
 #t
 > (string-every (lambda (x) (char=? x #\x)) "f")
 #f
 > (string-every (lambda (x) (char=? x #\x)) "xxxf")
 #f
 > (string-every (lambda (x) (char=? x #\x)) "xxx")
 #t
 )
;; > (string-every (lambda (x) (warn ".") (char=? x #\x)) "xxfxxxxxxxxxxxxxxxxxxxf")
;; ok

;; odd why does this not exist?:

(define string-downcase
  (cut string-map char-downcase <>))

;; some other langs call it lc, add alias?
(define string-lc string-downcase)

(TEST
 > (string-downcase "Hello")
 "hello"
 )


;; (XX where everywhere do I have format pieces lying around?)

(define (string-pad-left s pad-char to-len)
  (let ((len (string-length s)))
    (if (<= to-len len)
	s
	(let ((res (##make-string to-len))
	      (diff (- to-len len)))
	  (for..< (i 0 diff)
		  (string-set! res i pad-char))
	  (for..< (i diff to-len)
		  (string-set! res i
			       (string-ref s (- i diff))))
	  res))))

(TEST
 > (string-pad-left "3" #\0 4)
 "0003"
 > (string-pad-left "123" #\0 4)
 "0123"
 > (string-pad-left "123" #\0 3)
 "123"
 > (string-pad-left "123" #\0 2)
 "123"
 )


(define (string-ends-with? str substr)
  ((on string-length
       (lambda (len0 len1)
	 (let ((offset (- len0 len1)))
	   (and (not (negative? offset))
		(string=? (substring str offset len0);; XX performance
			  substr)))))
   str substr))

(TEST
 > (string-ends-with? "" "")
 #t
 > (string-ends-with? "" "x")
 #f
 > (string-ends-with? "x" "x")
 #t
 > (string-ends-with? "ax" "x")
 #t
 > (string-ends-with? "xa" "x")
 #f
 )

(define (string-starts-with? str substr)
  ;; copypaste
  ((on string-length
       (lambda (len0 len1)
	 (let ((offset (- len0 len1)))
	   (and (not (negative? offset))
		(string=? (substring str 0 len1);; XX performance
			  substr)))))
   str substr))

(TEST
 > (string-starts-with? "" "")
 #t
 > (string-starts-with? "" "a")
 #f
 > (string-starts-with? "a" "a")
 #t
 > (string-starts-with? "ax" "a")
 #t
 > (string-starts-with? "ax" "x")
 #f
 )

