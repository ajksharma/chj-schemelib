;;; Copyright 2018 by Christian Jaeger <ch@christianjaeger.ch>

;;; This file is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU Lesser General Public License (LGPL)
;;; as published by the Free Software Foundation, either version 2 of
;;; the License, or (at your option) any later version.


;; Ranges (closed in the mathematical sense [1]) on types offering
;; .inc, .dec, .-, .< and .<= methods (iterable types but also more
;; generally orderable ones)

;; [1] https://en.wikipedia.org/wiki/Closed_set

;; For other such libraries, see:

;;   https://hackage.haskell.org/package/range-0.1.2.0/

;; Not sure about Guava:

;;   https://www.tutorialspoint.com/guava/guava_range_class.htm
;;   https://github.com/google/guava/wiki/RangesExplained

;; Not these, they don't contain all of this functionality?:

;;   https://doc.rust-lang.org/std/ops/struct.Range.html
;;   http://swiftdoc.org/v2.2/type/Range/
;;   https://kotlinlang.org/docs/reference/ranges.html


;; TODO:
;; - what should the behaviour be in the various methods when (< to
;;   from) ?
;; - what should the values be based on when iterating with
;;   non-discrete values, from or to?
;; - ranges to infinity (only with from value).
;; - ranges including to ? Or just wrapper that .inc's first?
;; - downward ranges (how to share evaluation code?)


(require easy
	 jclass
	 ;; for Library at the bottom only:
	 (cj-env for..<)
	 (list-util map/maybe-sides)
	 (stream stream-map)
	 ;; for tests only:
	 test
	 (string-util-2 inexact.round-at))

(export (jclass range)
	(jclass ranges)
	range-of
	;; "Library":
	(method range.map
		range.map-stream
		range.map/maybe-sides
		range.for)
	range-of-exact-integer?
	(method range-of-exact-integer.for))


;; XX: the API across |range| and |ranges| is incomplete, |range| does
;; not support |ranges| in all places and |ranges| does not support
;; all the methods from |range| (yet).

(jinterface range-or-ranges

	    ;; inclusive
	    (method (from r) -> T?)
	    ;; exclusive
	    (method (to r) -> T?)

	    ;; orderable distance betweeen start and end
	    (method (length r) -> real?)

	    ;; number of items between from and to, excluding to,
	    ;; i.e. (length (.list r))
	    (method (size r) -> exact-natural0?)

	    ;; whether size is 0
	    (method (empty? r) -> boolean?)

	    (method (contains-element? r1 [T? x]) -> boolean?)

	    ;; whether r2 is fully contained in r1, i.e. whether
	    ;; (.union r1 r2) == r1 XX add generative tests
	    (method (contains-range? r1 [range-or-ranges? r2]) -> boolean?)

	    ;; i.e. whether (cond ((.union r1 r2) => (lambda (u) (= (+ (.size
	    ;; r1) (.size r2)) (.size u)))) (else #f)) XX add generative
	    ;; tests
	    (method (contiguous? r1 [range-or-ranges? r2]) -> boolean?)

	    ;; excl. contiguous ones (i.e. the same as (comp* pair? .list
	    ;; .union)) XX add generative tests; XX naming consistency
	    ;; with contiguous: should this be called |overlapping?|
	    ;; instead (describing the resulting theoretical range
	    ;; 'collection')?
	    (method (overlaps? r1 [range-or-ranges? r2]) -> boolean?)

	    ;; same as (complement (either .contiguous? .overlaps?)), or,
	    ;; (is that the same thing?) would it require multiple ranges
	    ;; to satisfy the result? XX add generative tests
	    (method (separated? r1 [range-or-ranges? r2]) -> boolean?)

	    ;; index in r1 for x, following the naming from wbtree;
	    ;; "rank" for non-discrete types sounds bad, though, but
	    ;; so be it
	    (method (unchecked-rank r [T? x]) -> real?)

	    ;; with overflow and integer checking:
	    (method (checked-rank r [T? x]
				  [T2? underflow-value]
				  [T3? overflow-value])
		    -> (either real? T2? T3?))

	    (method (maybe-rank r x) -> (maybe exact-natural0?))

	    (method (ref r1 [real? x]) -> T?)

	    (method (intersection r1 [range-or-ranges? r2]) -> range?)

	    ;; a union that only succeeds if there is no gap between
	    ;; r1 and r2
	    (method (maybe-union r1 [range-or-ranges? r2]) -> (maybe range?))

	    ;; a union that bridges over gaps
	    (method (filling-union r1 [range-or-ranges? r2]) -> range?)

	    ;; A union that works even if there are holes between the
	    ;; ranges. Name it with a star to stop users from just calling
	    ;; .union without realizing that it could return ranges.
	    (method (union* r1 [range-or-ranges? r2]) -> range-or-ranges?)

	    ;; Iteration
	    (method (list r #!optional (tail '())) -> (list-of T?))
	    (method (rlist r #!optional (tail '())) -> (list-of T?))
	    (method (stream r #!optional (tail '())) -> (iseq-of T?))
	    (method (rstream r #!optional (tail '())) -> (iseq-of T?))
	    )


(jclass (range from to) ;; excluding to
	implements: range-or-ranges

	(def-method (length r) -> real?
	  (.- to from))

	;; same as (comp-function length .list), XX add generative tests
	(def-method (size r) -> exact-natural0?
	  (let ((len (.- to from)))
	    (if (negative? len)
		0
		(integer len))))

	(def-method (empty? r)
	  (zero? (range.size r)))
	
	(def-method (contains-element? r1 x) -> boolean?
	  (and (.<= from x)
	       (.< x to)))

	(def-method (contains-range? r1 r2) -> boolean?
	  (let-range ((from2 to2) r2)
		     (and (.<= from from2)
			  (.<= to2 to))))

	(def-method (contiguous? r1 r2) -> boolean?
	  (let-range ((from2 to2) r2)
		     (or (and
			  ;; avoid requiring .= ?
			  (.<= to from2)
			  (.<= from2 to))
			 ;; or, on the other end??
			 (and
			  (.<= to2 from)
			  (.<= from to2)))))

	(def-method (overlaps? r1 r2) -> boolean?
	  (let-range ((from2 to2) r2)
		     (and
		      ;; make sure no range is empty:
		      (.< from to)
		      (.< from2 to2)
		      ;; make sure they overlap:
		      (if (.<= from from2)
			  (.< from2 to)
			  (.< from to2)))))

	(def-method (separated? r1 r2) -> boolean?
	  (let-range ((from2 to2) r2)
		     ;; if one is empty, then there's no gap anyway
		     (if (or (not (.< from to))
			     (not (.< from2 to2)))
			 #f
			 (if (.<= from from2)
			     (.< to from2)
			     (.< to2 from)))))


	(def-method (unchecked-rank r x) -> real?
	  (.- x from))

	(def-method (checked-rank r x underflow overflow)
	  (let ((rank (.- x from)))
	    (if (negative? rank)
		underflow
		(if (< rank (.- to from))
		    rank
		    overflow))))

	(def-method (maybe-rank r x) -> (maybe exact-natural0?)
	  (.checked-rank r x #f #f))
	

	(def-method (ref r1 [real? x])
	  (.+ from x))

	(def-method (intersection r1 r2) -> range?
	  (let-range ((from2 to2) r2)
		     (range (if (<= from from2)
				from2 from)
			    (if (< to to2)
				to to2))))

	(def-method (maybe-union r1 r2) -> (maybe range?)
	  (let-range ((from2 to2) r2)
		     (cond ((not (.< from to))
			    r2)
			   ((not (.< from2 to2))
			    r1)
			   (else
			    ;; would there be a hole?
			    (and (not (.separated? r1 r2))
				 (range (if (<= from from2)
					    from from2)
					(if (< to to2)
					    to2 to)))))))

	(def-method (filling-union r1 r2) -> range?
	  (let-range ((from2 to2) r2)
		     (cond ((not (.< from to))
			    r2)
			   ((not (.< from2 to2))
			    r1)
			   (else
			    (range (if (.<= from from2) from from2)
				   (if (.< to2 to) to to2))))))

	(def-method (union* r1 [range-or-ranges? r2]) -> range-or-ranges?
	  (if (not (.< from to))
	      r2
	      (if (range? r2)
		  (or (.maybe-union r1 r2)
		      (ranges r1 r2))
		  
		  ;; r2 is a |ranges|; use the functionality in ranges
		  ;; class
		  (.add-range r2 r1))))


	(def-method (list r #!optional (tail '()))
	  (let lp ((i (.dec to))
		   (l tail))
	    (if (.<= from i)
		(lp (.dec i) (cons i l))
		l)))

	(def-method (rlist r #!optional (tail '()))
	  (let lp ((i from)
		   (l tail))
	    (if (.< i to)
		(lp (.inc i) (cons i l))
		l)))

	(def-method (stream r #!optional (tail '()))
	  (let rec ((i from))
	    (delay
	      (if (.< i to)
		  (cons i (rec (.inc i)))
		  tail))))
	
	(def-method (rstream r #!optional (tail '()))
	  (let rec ((i (.dec to)))
	    (delay
	      (if (.<= from i)
		  (cons i (rec (.dec i)))
		  tail))))


	;; for reverse iteration (streams, lists): (jclass (down-to))
	;;perhaps call it reverse-range ? but no, really have to swap
	;;arguments to make comparisons work! How to get new ranges
	;;out of it? bless on original object's class?....
	)


(def ((range-of T?) v)
     (and (range? v)
	  (let-range ((from to) v)
		     (and (T? from)
			  (T? to)))))



;; Trees of ranges (i.e. ranges with gaps). (Todo: check Haskell's
;; implementation for comparison.)

(jclass (ranges [range-or-ranges? a]
		[(lambda (b)
		   (and (range-or-ranges? b)
			(.< (.from a) (.from b))
			;; and, otherwise it should be a merged range:
			(.<= (.to a) (.from b))))
		 b])
	implements: range-or-ranges


	(def-method (from s)
	  (.from a))

	(def-method (to s)
	  (.to b))

	(def-method (list s #!optional (tail '()))
	  (.list a (.list b tail)))

	(def-method (rlist s #!optional (tail '()))
	  (.rlist b (.rlist a tail)))

	(def-method (stream s #!optional (tail '()))
	  (.stream a (.stream b tail)))

	(def-method (rstream s #!optional (tail '()))
	  (.rstream b (.rstream a tail)))

	;; XX implement the other methods like contains? -- via binary
	;; search? Could also implement balancing...

	(def-method (add-range rs [range? r])
	  ;; no need to check s for emptyness, rangess are always
	  ;; guaranteed to be non-empty

	  (let-range
	   ((r-from r-to) r)
	   (let ((rs-from (.from rs)))
	     (if (.< r-to rs-from)
		 ;; disjoint
		 (ranges r rs)
		 
		 (let ((rs-to (.to rs)))
		   (if (.< rs-to r-from)
		       (ranges rs r)

		       ;; adjacent, or overlapping, or inclusive
		       (if (.<= r-from rs-from)
			   (if (.<= rs-to r-to)
			       ;; r includes rs
			       r
			       ;; need to merge with the low end
			       (error "XX UNFINISHED 1"))
			   ;; need to merge with the high end
			   (error "XX UNFINISHED 2"))))))))

	;; helper for doing merges
	'(def-method (_merge s [range? r])
	   )
	

	)




;; XX MOVE

(def. real.inc inc*)
(def. real.dec dec*)
(def. real.< <)
(def. real.<= <=)
(def. real.- -)

(def. char.inc (comp integer->char (C fx+ _ 1) char->integer))
(def. char.dec (comp integer->char (C fx- _ 1) char->integer))
(def. char.< (on char->integer fx<))
(def. char.<= (on char->integer fx<=))
(def. char.- (on char->integer fx-))



(TEST
 > (map (C .contains-element? (range 10 12) _) (iota 4 9))
 (#f #t #t #f)
 > (map (C .contains-element? (range 12 10) _) (iota 4 9))
 (#f #f #f #f)
 )

(TEST
 > (.intersection (range 10 12) (range 13 14))
 #((range) 13 12) ;; careful..?
 > (.intersection (range 10 12) (range 12 14))
 #((range) 12 12)
 > (.intersection (range 10 12) (range 11 14))
 #((range) 11 12)
 > (.intersection (range 10 14) (range 11 14))
 #((range) 11 14)
 > (.intersection (range 10 14) (range 11 12))
 #((range) 11 12)
 > (.intersection (range 10 14) (range 9 12))
 #((range) 10 12)
 > (.intersection (range 11 12) (range 10 14))
 #((range) 11 12)
 ;; re careful:
 > (.intersection (range 10 12) (range 14 11))
 #((range) 14 11)
 > (list (.length #) (.size #))
 (-3 0)
 )


(TEST
 > (.list (range 3 5))
 (3 4)
 > (.rlist (range 3 5))
 (4 3)
 > (promise? (.stream (range 3 5)))
 #t
 > (F (.stream (range 3 5)))
 (3 4)
 > (F (.rstream (range 3 5)))
 (4 3)
 > (.list (range 5 3))
 ()
 > (.rlist (range 5 3))
 ()
 > (.list (range 4.3 9.1))
 ;; used to be (4.3 5.3 6.3 7.3 8.3)
 (5.1 6.1 7.1 8.1)
 > (.rlist (range 4.3 9.1))
 ;; uh not (8.1 7.1 6.1 5.1)
 (8.3 7.3 6.3 5.3 4.3) ;; XX weird?
 ;; XX and, *really* weird?:
 > (F (.stream (range 4.3 9.1)))
 (4.3 5.3 6.3 7.3 8.3)
 > (F (.rstream (range 4.3 9.1)))
 (8.1 7.1 6.1 5.1)

 ;; XX also weird?
 > (.list (range 4 4.1))
 ()
 > (.list (range 4 5))
 (4)
 > (inexact.round-at (.length (range 4 4.1)) 10)
 .1
 > (.size (range 4 4.1))
 0
 > (.size (range 4 5))
 1
 )


(TEST
 > (.list (.intersection (range 3 9) (range 4 3)))
 ()
 > (.list (.intersection (range 3 9) (range 3 4)))
 (3)
 > (.list (.intersection (range 3 9) (range 3 100)))
 (3 4 5 6 7 8)
 > (.list (.intersection (range 3 9) (range 10 8)))
 ()

 > (.list (.maybe-union (range 3 9) (range 4 3)))
 (3 4 5 6 7 8)
 > (.list (.maybe-union (range 3 9) (range 10 9)))
 (3 4 5 6 7 8)
 > (.show (.maybe-union (range 3 9) (range 5 100)))
 (range 3 100)
 > (.show (.maybe-union (range 3 9) (range 9 100)))
 (range 3 100)
 > (.show (.maybe-union (range 3 9) (range 10 100)))
 #f

 > (.show (.filling-union (range 3 9) (range 10 100)))
 (range 3 100)
 > (.show (.filling-union (range 3 20) (range 10 100)))
 (range 3 100)
 > (.show (.filling-union (range 20 3) (range 10 100)))
 (range 10 100)
 > (.show (.filling-union (range 10 100) (range 20 3)))
 (range 10 100)
 > (.show (.filling-union (range 20 3) (range 100 10)))
 (range 100 10) ;; whatever~
 > (.show (.filling-union (range 10 3) (range 100 20)))
 (range 100 20) ;; whatever~
 > (.show (.filling-union (range 4 4) (range 100 20)))
 (range 100 20) ;; whatever~
 > (.show (.filling-union (range 4 4) (range 20 100)))
 (range 20 100)

 > (.show (.union* (range 3 9) (range 10 100)))
 (ranges (range 3 9) (range 10 100))
 > (def rs (.union* (range -2 1) (range 3 5)))
 > (.list rs)
 (-2 -1 0 3 4)
 > (.rlist rs)
 (4 3 0 -1 -2)
 > (.show (.union* (.union* (range -2 1) (range 1 2)) (range 3 5)))
 (ranges (range -2 2) (range 3 5))
 ;; > (.show (.union* (.union* (range -2 0) (range 1 2)) (range 3 5)))
 ;; XX todo
 > (.show (.union* (range 3 5) (.union* (range -2 0) (range 1 2))))
 (ranges (ranges (range -2 0) (range 1 2))
	 (range 3 5))
 > (def rs (eval #))
 > (.list rs)
 (-2 -1 1 3 4)
 > (.rlist rs)
 (4 3 1 -1 -2))


(TEST
 > (.unchecked-rank (range 3.5 9) 4)
 0.5
 > (%try-error (.maybe-rank (range 3.5 9) 4))
 #(error "value fails to meet predicate:" ((maybe exact-natural0?) .5))
 > (.maybe-rank (range 3 9) 5)
 2
 > (.maybe-rank (range #\b #\z) #\a)
 #f
 > (.maybe-rank (range #\b #\z) #\b)
 0
 > (.maybe-rank (range #\b #\z) #\c)
 1
 > (.maybe-rank (range #\b #\z) #\z)
 #f
 > (.maybe-rank (range #\b #\z) #\y)
 23
 > (.maybe-rank (range #\a (.inc #\z)) #\z)
 25
 > (.list (range #\a #\d))
 (#\a #\b #\c)
 > (.rlist (range #\a #\d))
 (#\c #\b #\a)
 > (F (.rstream (range #\a #\d)))
 (#\c #\b #\a))


(TEST
 > (map (C .contains-element? (range 10 11) _) (.. 9 11))
 (#f #t #f))

(TEST
 > (.contains-range? (range 10 20) (range 12 15))
 #t
 > (.contains-range? (range 10 20) (range 12 20))
 #t
 > (.contains-range? (range 10 20) (range 12 21))
 #f
 > (.contains-range? (range 10 20) (range 10 12))
 #t
 > (.contains-range? (range 10 20) (range 9 12))
 #f


 ;; user should check for "validity" of the ranges first?
 > (.contains-range? (range 10 20) (range 12 11))
 #t ;; ? 
 > (.contains-range? (range 10 20) (range 30 30))
 #f ;; *??* what should it be, "division by zero?"
 > (.contains-range? (range 10 20) (range 30 0))
 #t ;; dito ??

 ;; dito, reversals of those above
 > (.contains-range? (range 20 10) (range 12 15))
 #f
 > (.contains-range? (range 20 10) (range 12 20))
 #f
 > (.contains-range? (range 20 10) (range 12 21))
 #f
 > (.contains-range? (range 20 10) (range 10 12))
 #f
 > (.contains-range? (range 20 10) (range 9 12))
 #f
 )

(TEST
 > (.contiguous? (range 3 4) (range 4 5))
 #t
 > (.contiguous? (range 3 4) (range 3 5))
 #f
 > (.contiguous? (range 3 4) (range 5 5))
 #f
 > (.contiguous? (range 3 4) (range 5 6))
 #f
 > (.contiguous? (range 3 4) (range 4 4))
 #t
 > (.contiguous? (range 3 5) (range 1 3))
 ;; AH, vs. perhaps contiguous only in one order?? well, my spec
 ;; wouldn't match that.
 #t
 )

(TEST
 ;; XX should perhaps use these for the tests above, too
 > (def t-ranges
	(list
	 ;; non reverse ranges
	 (list (list (list (range 3 4) (range 4 5))
		     (list (range 3 4) (range 5 6))
		     (list (range 3 4) (range 4 4))
		     (list (range 3 4) (range 3 4))
		     (list (range 3 4) (range 3 5))
		     (list (range 3 4) (range 2 5))
		     (list (range 2 5) (range 3 4)))

	       (list (list (range 3 3) (range 4 5))
		     (list (range 3 3) (range 5 6))
		     (list (range 3 3) (range 3 4))
		     (list (range 3 3) (range 3 3))
		     (list (range 3 3) (range 2 3))
		     (list (range 3 3) (range 2 5))))

	 ;; with reversed ranges
	 (list (list (list (range 4 3) (range 4 5))
		     (list (range 4 3) (range 5 6))
		     (list (range 4 3) (range 4 4))
		     (list (range 4 3) (range 3 4))
		     (list (range 4 3) (range 3 5))
		     (list (range 4 3) (range 2 5))
		     (list (range 5 2) (range 3 4)))

	       (list (list (range 3 4) (range 5 4))
		     (list (range 3 4) (range 6 5))
		     (list (range 3 4) (range 4 3))
		     (list (range 3 4) (range 5 3))
		     (list (range 3 4) (range 5 2))
		     (list (range 2 5) (range 4 3))))))
 ;; check for duplicates
 > (let ((s (cmp-sort (flatten1 (flatten1 t-ranges)) generic-cmp)))
     (= (length s) (length (cmp-list-uniq generic-cmp s))))
 #t
 > (map (C map (applying .overlaps?) _) (first t-ranges))
 ;; remember, does the union result return something?
 ((#f #f #f #t #t #t #t) (#f #f #f #f #f #f))
 > (.overlaps? (range 3 4) (range 3 4))
 #t
 > (.overlaps? (range 3 4) (range 3 5))
 #t
 > (.overlaps? (range 3 3) (range 2 5))
 #f
 > (map (C map (applying .overlaps?) _) (second t-ranges))
 ((#f #f #f #f #f #f #f) (#f #f #f #f #f #f))

 > (map (C map (applying .separated?) _) (first t-ranges))
 ((#f #t #f #f #f #f #f) (#f #f #f #f #f #f))
 )


;; Library on top, well, could be part of the interface. Dunno.

;; XX more efficient implementations would avoid intermediary
;; lists/streams

(def. (range.map r fn)
  (map fn (.list r)))

(def. (range.map-stream r fn)
  (stream-map fn (.stream r)))

(def. (range.map/maybe-sides r fn)
  (map/maybe-sides fn (.list r)))


(def.* (range.for r proc)
  (let lp ((i from))
    (if (.< i to)
	(begin
	  (proc i)
	  (lp (.inc i))))))

(def range-of-exact-integer? (range-of exact-integer?))

(def. (range-of-exact-integer.for r proc)
  (let-range ((from to) r)
	     (for..< (i from to)
		     (proc i))))

