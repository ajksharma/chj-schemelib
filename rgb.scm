;;; Copyright 2013-2017 by Christian Jaeger <ch@christianjaeger.ch>

;;;    This file is free software; you can redistribute it and/or modify
;;;    it under the terms of the GNU General Public License (GPL) as published 
;;;    by the Free Software Foundation, either version 2 of the License, or
;;;    (at your option) any later version.


(require easy
	 test
	 jclass
	 test-logic
	 colorspaces
	 (cj-source-wraps source:symbol-append)
	 (rgb-types rgb:0..1?))


(def (01-bound x)
     (cond ((< x 0) 0)
	   ((> x 1) 1)
	   (else x)))

;; (def (01-bound-if x clip?)
;;      (if clip?
;; 	 (01-bound x)
;; 	 x))


(def +/2 (lambda (a b) (+ a b)))

;; call it mean or average ?
(def mean (compose-function (C / _ 2) +/2))

(TEST
 > (mean 1 2)
 3/2
 > (mean 1 3)
 2
 > (mean 1 2.)
 1.5)

;; XX better name? slope, shade-towards, ?
;; (Have 'shade_exponentially_towards' in Perl. Odd one though?)
(def (mean-towards x0 x1 factor)
     (+ x0 (* factor (- x1 x0))))

(TEST
 > (mean-towards 10 14 0)
 10
 > (mean-towards 10 14 1)
 14
 > (mean-towards 10 14 1/2)
 12
 > (mean-towards 10 14 1/3)
 34/3
 > (mean-towards 10 14 2)
 18)

;; lib, too:

(def hexdigits "0123456789ABCDEF")

(def (number->uc-hex-string/padding #(natural0? x) #(natural0? paddigits))
     (let lp ((digits '())
	      (x x))
       (if (zero? x)
	   (string-pad-left (list->string digits) #\0 paddigits)
	   (let ((d (bitwise-and x 15))
		 (r (arithmetic-shift x -4)))
	     (lp (cons (string-ref hexdigits d) digits)
		 r)))))

(TEST
 > (number->uc-hex-string/padding 0 4)
 "0000"
 > (number->uc-hex-string/padding 1 4)
 "0001"
 > (number->uc-hex-string/padding 15 4)
 "000F"
 > (number->uc-hex-string/padding 18 4)
 "0012"
 > (number->uc-hex-string/padding 65534 4)
 "FFFE"
 > (number->uc-hex-string/padding 65536 4)
 "10000")

;; /lib

(def uint8.01
     (C * _ (insert-result-of (/ 1. 255.))))

(def 01.uint8
     (lambda (x)
       (let ((r (inexact->exact
		 (floor (fl+ (fl* (exact->inexact x) 255.) 0.5)))))
	 (cond ((>= r 256)
		255)
	       ((negative? r)
		0)
	       (else
		r)))))


(jclass
 rgb

 ;; 'full' inversion, in linear space; XX does this make sense? See
 ;; tests, search for "sense"
 (method (invert v) -> rgb?)
 ;; dito; saturating at the top
 (method (scale v factor) -> rgb?)

 (jclass rgb01

	 ;; RGB in 0..1 floating point range, sRGB 'transfer' format
	 (jclass (rgb01t #(rgb:0..1? r01t)
			 #(rgb:0..1? g01t)
			 #(rgb:0..1? b01t))

		 (def-method- rgb01t identity)

		 (def-method- r01l (compose-function srgb:transfer.lum rgb01t.r01t))
		 (def-method- g01l (compose-function srgb:transfer.lum rgb01t.g01t))
		 (def-method- b01l (compose-function srgb:transfer.lum rgb01t.b01t))

		 (def-method- r8 (compose-function 01.uint8 rgb01t.r01t))
		 (def-method- g8 (compose-function 01.uint8 rgb01t.g01t))
		 (def-method- b8 (compose-function 01.uint8 rgb01t.b01t))

		 (def-method- (rgb01l x)
		   ;; XX evil, too much duplication. this is
		   ;; optimization here
		   ;; ah and at least  have   map functions  right? evil.
		   (let-rgb01t ((r g b) x)
			       (let ((conv srgb:transfer.lum))
				 (rgb01l (conv r)
					 (conv g)
					 (conv b)))))

		 (def-method- (rgb8 x)
		   (let-rgb01t ((r g b) x)
			       (rgb8 (01.uint8 r)
				     (01.uint8 g)
				     (01.uint8 b))))

		 (def-method- invert
		   (comp rgb01l.rgb01t rgb01l.invert rgb01t.rgb01l))

		 (def-method- (scale s factor)
		   (rgb01l.rgb01t (rgb01l.scale (rgb01t.rgb01l s)
						factor))))
       


	 ;; RGB in 0..1 floating point range, linear
	 ;; (proportional to physical light energy, right?)
	 ;; format
	 (jclass (rgb01l #(rgb:0..1? r01l)
			 #(rgb:0..1? g01l)
			 #(rgb:0..1? b01l))

		 (def (rgb01l/clipping r g b)
		      (rgb01l (01-bound r)
			      (01-bound g)
			      (01-bound b)))

		 (def-method- rgb01l identity)

		 (def-method- r01t (compose-function srgb:lum.transfer rgb01l.r01l))
		 (def-method- g01t (compose-function srgb:lum.transfer rgb01l.g01l))
		 (def-method- b01t (compose-function srgb:lum.transfer rgb01l.b01l))

		 (def-method- r8 (compose-function 01.uint8 rgb01l.r01t))
		 (def-method- g8 (compose-function 01.uint8 rgb01l.g01t))
		 (def-method- b8 (compose-function 01.uint8 rgb01l.b01t))

		 (def-method- (rgb01t x)
		   ;; XX dito duplication ~
		   (let-rgb01l ((r g b) x)
			       (let ((conv srgb:lum.transfer))
				 (rgb01t (conv r)
					 (conv g)
					 (conv b)))))

		 (def-method- (rgb8 v)
		   (.rgb8 (rgb01l.rgb01t v)))

		 (def-method (invert v)
		   (rgb01l (- 1 r01l)
			   (- 1 g01l)
			   (- 1 b01l)))

		 (def-method (scale s factor)
		   (rgb01l (min 1.0 (* r01l factor))
			   (min 1.0 (* g01l factor))
			   (min 1.0 (* b01l factor))))))

	

 ;; rgb8 is always in sRGB 'transfer' format
 ;; (non-linear), ok?
 (jclass (rgb8 #(uint8? r8)
	       #(uint8? g8)
	       #(uint8? b8))

	 (def-method- rgb8 identity)

	 (def-method- r01t (compose-function uint8.01 rgb8.r8))
	 (def-method- g01t (compose-function uint8.01 rgb8.g8))
	 (def-method- b01t (compose-function uint8.01 rgb8.b8))

	 (def-method- r01l (comp* srgb:transfer.lum uint8.01 rgb8.r8))
	 (def-method- g01l (comp* srgb:transfer.lum uint8.01 rgb8.g8))
	 (def-method- b01l (comp* srgb:transfer.lum uint8.01 rgb8.b8))

	 (def-method- (rgb01t x)
	   (let-rgb8 ((r g b) x)
		     (rgb01t (uint8.01 r)
			     (uint8.01 g)
			     (uint8.01 b))))
		 
	 (def-method- rgb01l (compose-function rgb01t.rgb01l rgb8.rgb01t))

	 (def-method- invert
	   (comp rgb01l.rgb8 rgb01l.invert rgb8.rgb01l))

	 (def-method- (scale s factor)
	   (rgb01l.rgb8 (rgb01l.scale (rgb8.rgb01l s)
				      factor))))

 
 ;; generic operations: ---------------------------------------------------

 (def-method- (html-colorstring x)
   (def (conv #(uint8? x))
	(number->uc-hex-string/padding x 2))
   (insert-result-of
    `(string-append "#"
		    ,@(map (lambda_
			    `(conv (,_ x)))
			   '(.r8 .g8 .b8)))))


 (def (rgb01:op/2 op)
      (lambda (a b #!optional #(boolean? clip?))
	(let-rgb01l
	 ((r0 g0 b0) (.rgb01l a))
	 (let-rgb01l
	  ((r1 g1 b1) (.rgb01l b))
	  ((if clip? rgb01l/clipping rgb01l)
	   (op r0 r1)
	   (op g0 g1)
	   (op b0 b1))))))

 (def-method- + (rgb01:op/2 +))
 (def-method- - (rgb01:op/2 -))
 (def-method- mean (rgb01:op/2 mean))

 (def (rgb01:op/2+1 op)
      (lambda (a b c #!optional #(boolean? clip?))
	(let-rgb01l
	 ((r0 g0 b0) (.rgb01l a))
	 (let-rgb01l
	  ((r1 g1 b1) (.rgb01l b))
	  ((if clip? rgb01l/clipping rgb01l)
	   (op r0 r1 c)
	   (op g0 g1 c)
	   (op b0 b1 c))))))

 (def-method- mean-towards (rgb01:op/2+1 mean-towards))

 (def (rgb01:.op op)
      (lambda (a #(number? b) #!optional #(boolean? clip?))
	(insert-result-of
	 `((if clip? rgb01l/clipping rgb01l)
	   ,@(map (lambda_
		   `(op (,_ a) b))
		  '(.r01l .g01l .b01l))))))

 (def-method- .* (rgb01:.op *))
 (def-method- ./ (rgb01:.op /))

 )


(TEST
 > (.html-colorstring (rgb8 0 128 255))
 "#0080FF"
 > (.html-colorstring (.rgb01l (rgb8 0 128 255)))
 "#0080FF"
 > (.html-colorstring (rgb01t 1 0.5 0))
 "#FF8000"

 > (.invert (rgb8 0 128 255))
 #((rgb8) 255 229 0) ;; hah yes, 128 is not the center.
 > (.invert (rgb8 10 40 245))
 #((rgb8) 255 253 83)
 ;; oh my. Now question is does this kind of inversion actually make sense?
 > (.show (.scale (rgb8 0 128 255) 0.5))
 (rgb8 0 92 188)
 > (.show (.scale (rgb8 2 10 20) 0.5))
 (rgb8 1 5 11)
 > (.show (.scale (rgb8 10 128 200) 2))
 (rgb8 18 176 255))


;; parse =================================================================

(def. (string.rgb8 s)

  (def (conv element-i.i stretch)

       (def (get-number i)
	    (let ((ss (substring s (element-i.i i) (element-i.i (inc i)))))
	      (def (err)
		   (error "string.rgb8: expecting positive hex number:" s ss))
	      (cond ((string->number ss 16)
		     => (lambda (n)
			  (if (negative? n)
			      (err)
			      (stretch n))))
		    (else (err)))))

       (if (char=? (string-ref s 0) #\#)
	   (rgb8 (get-number 0)
		 (get-number 1)
		 (get-number 2))
	   (error "html color strings need to start with character '#'")))

  (case (string.length s)
    ((7) (conv (lambda (element-i)
		 (+ 1 (* element-i 2)))
	       identity))
    ((4) (conv (lambda (element-i)
		 (+ 1 element-i))
	       (lambda (n)
		 (* 255 (/ n 15)))))
    (else
     (error "html color strings need to be of length 7 or 4"))))


(TEST
 > (.rgb8 "#FF00FF")
 #((rgb8) 255 0 255)
 > (%try (.rgb8 "# F00FF"))
 (exception
  text:
  "string.rgb8: expecting positive hex number: \"# F00FF\" \" F\"\n")
 > (%try (.rgb8 "#xF00FF"))
 (exception
  text:
  "string.rgb8: expecting positive hex number: \"#xF00FF\" \"xF\"\n")
 > (%try (.rgb8 "#-800FF"))
 (exception
  text:
  "string.rgb8: expecting positive hex number: \"#-800FF\" \"-8\"\n")
 > (.rgb8 "#F00080")
 #((rgb8) 240 0 128)
 > (.rgb8 "#88f")
 #((rgb8) 136 136 255)
 > (.html-colorstring #)
 "#8888FF")


;; tests =================================================================

(TEST
 > (F (Lforall '(-1 0 1 2 253 254 255 255. 256)
	       (lambda_ (= (01.uint8 (uint8.01 _)) _))))
 ;; failures are outside of number range, "though"
 (-1 256))

(TEST
 > (.r01t (rgb8 0 255 128))
 0
 > (.b01t (rgb8 0 255 128))
 .5019607843137255 ;; was 128/255 in earlier version of the lib
 )

;; XX rgb01l.rgb01t
;; XX rgb01l.rgb8

(TEST
 ;; for all accessors, converted object should give the same value as
 ;; original
 > (def accessors (list .r01t .g01t .b01t))
 > (def x (rgb8 13 7 255))
 > (def x* (.rgb01t x))
 > (F (Lforall accessors (lambda_ ((on _ =) x x*))))
 ())


(TEST
 > (..* (rgb8 100 50 0) 2)
 ;; #(rgb01 40/51 20/51 0)
 #((rgb01l) .2548754380226136 .06379206392765045 -7.790527343750001e-5)

 > (%try (.+ (rgb8 255 128 0) (rgb8 10 10 10)))
 (exception text: "r01l does not match rgb:0..1?: 1.003035109168291\n")
 ;; Now the same with clipping:
 > (.+ (rgb8 255 128 0) (rgb8 10 10 10) #t)
 #((rgb01l) 1 .21889579733014106 .0029963123619556426)
 > (.html-colorstring #)
 "#FF810A"

 ;; Seeing the effect of the luminosity curve:
 > (.html-colorstring (.+ (.rgb8 "#FF2000") (rgb8 20 20 20) #t))
 "#FF2814"
 > (.html-colorstring (.+ (.rgb8 "#FF4000") (rgb8 20 20 20) #t))
 "#FF4414"
 > (.html-colorstring (.+ (.rgb8 "#FF6000") (rgb8 20 20 20) #t))
 "#FF6314"
 > (.html-colorstring (.+ (.rgb8 "#FFF000") (rgb8 20 20 20) #t))
 "#FFF114"

 > (%try-error (..* (rgb8 100 200 0) 2))
 ;; #(error "does not match rgb:0..1?:" 80/51)
 #(error "g01l does not match rgb:0..1?:" 1.1551609354972836)
 > (.mean (rgb01l 0 0.5 0.6) (rgb01l 1 1 0.8))
 #((rgb01l) 1/2 .75 .7))


(def (iter-stream f start)
     (let rec ((x start))
       (delay (cons x
		    (rec (f x))))))

(TEST
 > (F (stream-take (iter-stream (C ..* _ 0.9) (rgb01l 1 1 0.5)) 3))
 (#((rgb01l) 1 1 .5) #((rgb01l) .9 .9 .45) #((rgb01l) .81 .81 .405)))


