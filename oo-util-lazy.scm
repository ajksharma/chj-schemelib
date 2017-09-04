
(require easy-1
	 dot-oo ;; included in easy?
	 ;; oo-util ;; ?
	 (cj-source-quasiquote quasiquote-source)
	 stream ;; (only optionally? (lazily? well.))
	 (code-map code-map-substrings)
	 (oo-vector-lib sum)
	 debuggable-promise
	 )

(possibly-use-debuggable-promise)

;; Methods on lazy data

(insert-result-of
 `(begin
    ,@(map (lambda (method-name)
	     (quasiquote-source
	      (define. (,(source:symbol-append 'promise method-name) v)
		(,method-name (force v)))))
	   '(
	     .length ;; vs. istream.length which only works on streams
	     .car
	     .cdr
	     .first
	     .rest
	     ;; .cadr
	     ;; .cddr  ah won't work, need to dispatch to deeper-forcing ones
	     ;; .ref ;; hmm there is a list.ref, will be slow
	     ;;.equal nope, instead istream.equal? can work
	     ))))



;; Types: don't want to use list?, as that's inefficient and for
;; stream even worse. Thus don't want to name it stream? for
;; confusion, also, list.foo is bad since it both suggests it does
;; something it doesn't do and can't actually without redefinining
;; list?, hence i prefix, OK? For insecure, immediate, or so.

(define ilist? pair-or-null?)

(define (istream? v)
  ;; *only* for lazy inputs
  (and (promise? v)
       (ilist? (force v))))


;; methods after forcing:

(define. ilist.length improper-length)
;;(define. ilist.list identity) ;; well... dangerous.

(define. pair.car car)
(define. pair.cdr cdr)
(define. pair.first first)
(define. pair.rest rest)
;; (define. pair.)
;; (define. pair.)

(define. list.list identity)
;; ^ but actual forcing of a stream happens by dispatching to
;; stream.list (which should have, and has, priority,
;; hence, this one is only called for non-lazy inputs).


;; lazy-to-lazy methods:

;; XX should we just fall back on one generic method (hey, like in
;; fperl!), that forces then dispatches to the eager method, I mean,
;; then signalizes that it is to return a lazy result? I.e. dispatch
;; to a different namespace?)


;; for easy matching below. Consistency, you know..
(define list-drop drop)
(define list-take take)
(define list-sublist sublist)
(define list-length length)
(define list-sum sum)
(define list-append append)
(define list-append/2 append)
;;(define list-xone xone)
(define list-min&max stream-min&max) ;; XX add non-forcing instead? consistency forever? evil now
(define list-min stream-min)
(define list-max stream-max)

(define list-map map)
;;(define list-filter filter) ah, no
(define (list-filter pred lis #!optional (tail '()))
  (let rec ((l lis))
    (if (pair? l)
	(let-pair ((a l*) l)
		  (If (pred a)
		      (cons a (rec l*))
		      (rec l*)))
	tail)))

(define list-filter-map filter-map)

(define list-first first)
(define list-second second)
(define list-third third)
(define list-fourth fourth)
(define list-fifth fifth)
(define list-sixth sixth)
(define list-seventh seventh)
(define list-eighth eighth)
(define list-ninth ninth)
(define list-tenth tenth)

(code-map-substrings
 ((istream. '(istream. ilist.))
  (stream- '(stream- list-)))
 (begin

   (define. (istream.filter/tail s pred tail)
     (stream-filter/tail pred s tail))

   (define. (istream.for-each s proc . ss)
     (apply stream-for-each proc s ss))

   (define. (istream.fold-right l fn start)
     (stream-fold-right fn start l))

   ;; stream:fold-right  -- hmm, bad name anyway

   (define. (istream.map/tail s func tail)
     (stream-map/tail func s tail))

   (define. (istream.map s f . ss)
     (apply stream-map f s ss))

   (define. (istream.filter-map s f . ss)
     (apply stream-filter-map f s ss))

   (define. (istream.improper-map func s)
     (stream-improper-map func s))

   (define. (istream.list s)
     (stream->list s))

   (define. istream.drop
     stream-drop)

   (define. istream.take stream-take)

   (define. istream.sublist stream-sublist)

   (define. istream.length stream-length) ;; XX should really be a stream-improper-length !

   (define. istream.difference stream-difference)

   (define. istream.show-difference show-stream-difference)

   (define. istream.equal? stream-equal?)

   (define. (istream.filter s pred #!optional (tail '()))
     (stream-filter pred s tail))

   (define. (istream.fold l fn start)
     (stream-fold fn start l))

   (define. istream.append-optimized stream-append-optimized)

   (define. istream.append/2 stream-append/2)

   (define. istream.append stream-append)

   (define. (istream.union s less? . ss)
     (apply stream-union less? s ss))

   (define. (istream.uniq s equal? #!optional (tail '()))
     (stream-uniq equal? s tail))

   (define. (istream.uniq-count s equal? #!optional (tail '()))
     (stream-uniq-count equal? s tail))

   (define. (istream.cmp-union s cmp . ss)
     (apply cmp-stream-union cmp s ss))

   (define. (istream.group s equal? #!optional (tail '()))
     (stream-group equal? s tail))

   (define. (istream.cmp-group s cmp #!optional (tail '()))
     (cmp-stream-group cmp s tail))

   (define. (istream.chop/map s n f #!optional (tail '()))
     (stream-chop/map n s f tail))

   (define. (istream.chop n s #!optional (tail '()))
     (stream-chop n s tail))

   (define. (istream.zip s . ss)
     (apply stream-zip s ss))

   (define. (istream.zip2 s1 s2)
     (stream-zip2 s1 s2))

   (define. (istream.drop-while l pred)
     (stream-drop-while pred l))

   (define. istream.ref stream-ref)

   (define. (istream.every lis1 pred . lists)
     (apply stream-every pred lis1 lists))

   (define. istream.min&max stream-min&max)
   ;; are these evil, since |min| and |max| assume n-ary interfaces?:
   ;; (At least it should be unambiguous though as only work on
   ;; numbers, not lists, as elements.)
   (define. istream.min stream-min)
   (define. istream.max stream-max)

   (define. (istream.map/iota lis fn)
     (stream-map/iota fn lis))

   (define. istream.sum stream-sum)

   ;; srfi-1

   (define. istream.second stream-second)
   (define. istream.third stream-third)
   (define. istream.fourth stream-fourth)
   (define. istream.fifth stream-fifth)
   (define. istream.sixth stream-sixth)
   (define. istream.seventh stream-seventh)
   (define. istream.eighth stream-eighth)
   (define. istream.ninth stream-ninth)
   (define. istream.tenth stream-tenth)
   ))


(TEST
 > (.car (.cdr (stream-iota 10)))
 1
 > (.sum (iota 10))
 45
 > (.sum (stream-iota 10))
 45
 > (.sum (.map (iota 10) inc))
 55
 > (.sum (.map (stream-iota 10) inc))
 55
 > (.max '(1 9 4))
 9
 > (.max (stream-iota 10 5))
 14

 ;; add more extensive testing..
 )


