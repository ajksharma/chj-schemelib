;;;XXX sort out what I still want/need
(require
 cj-env ;;  symbol-append
 (cj-gambit-sys max-fixnum min-fixnum)
 cj-list-util ;; map-with-iota
 (srfi-1 cons*)
 (cj-string-flatten flat-append-strings)
 cj-env
 )

;; (compile #f);; since it's only a macro.

;; (exports-macros
;;  define-constant-from-c
;;  maybe-define-constant-from-c
;;  HACK_maybe-define-constant-from-c
;;  define-struct-field-accessors
;;  define-struct-accessors
;;  define-struct-from-c
;;  )


;; cj Fri, 29 Dec 2006 07:02:24 +0100
;; utilities for interfacing C code.
;; See also cj-c-types, for types helping interfacing C code,
;; and cj-c-errno for dealing with errno.

(cj-declare)

; (define-macro (define-constant-from-c name)
;   `(define ,name
;      ((c-lambda ()
;                 int
;                 ,(string-append "___result="
;                                 (symbol->string name)
;                                 ";")))))

;; replacing the above implementation with the below made the size of
;; the cj-posix.oX object file drop by 12.3%. 

; (define-macro (define-constant-from-c name)
;   `(define ,name
;      (##c-code ,(string-append "___RESULT= ___FIX("
; 			       (symbol->string name)
; 			       ");"))))

;; now also make it safe by checking if the constant is really in
;; fixnum range:

; (define-macro (define-constant-from-c name)
;   (let ((namestr (symbol->string name)))
;     `(define ,name
;        (##c-code ,(string-append "
; #define ___MAX_FLIX 32343
; #define ___MIN_FLIX -20
; {
;  int subar= ___MIN_FIX;
; }
; #if ((" namestr " > ___MAX_FLIX) || (" namestr " < (___MIN_FLIX)))
; #error \"define-constant-from-c: C constant '" namestr
; "' is out of fixnum range. (Improve macro implementation in cj-c-util.scm)\"
; #else
; ___RESULT= ___FIX(" namestr ");
; #endif
; #undef ___MAX_FLIX
; #undef ___MIN_FLIX
; ")))))
;sigh, you can't use __MIN_FIX since it expands to (for me): (-(((int)(1))<<((32 -2)-1)))
;which is over cpp's head, gcc says: missing binary operator before token "("
;so we're going to use definitions from cj-gambit-sys instead.

(define (code:constant-from-c namestr)
  (let ((maxstr (number->string max-fixnum))
	(minstr (number->string min-fixnum)))
    (string-append "
#if ((" namestr " > " maxstr ") || (" namestr " < " minstr "))
#error \"define-constant-from-c: C constant '" namestr "' is out of fixnum range. (Improve macro implementation in cj-c-util.scm to handle bignums.)\"
#else
___RESULT= ___FIX(" namestr ");
#endif
")))

(define-macro (define-constant-from-c name)
  (let ((namestr (symbol->string name)))
    `(define ,name
       (##c-code ,(code:constant-from-c namestr)))))


;; define the constant to be either false, if it doesn't exist in C
;; space, or the integer value if it does:

(define-macro (maybe-define-constant-from-c name)
  (let ((namestr (symbol->string name)))
    `(define ,name
       (##c-code ,(string-append "
#ifdef " namestr "
" (code:constant-from-c namestr) "
#else
___RESULT= ___FAL;
#endif
")))))


;; hehe this one does not even need the client modul to be compiled :)
;; (but I really wrote it since I couldn't figure out how to get at
;; the O_DIRECTORY definition in C)

(define-macro (HACK_maybe-define-constant-from-c name)
  (let* ((namestr (symbol->string name))
	 (p (open-process (list path: "perl"
				arguments:
				(list "-w"
				      (string-append "-MFcntl=" namestr)
				      "-e"
				      (string-append "print " namestr)))))
	 (num (read p))
	 (status (process-status p)))
    (close-port p)
    (if (= status 0)
	(if (integer? num)
	    `(define ,name ,num)
	    (error "HACK_maybe-define-constant-from-c: perl returned non-integer value:" num))
	(error "HACK_maybe-define-constant-from-c: perl exited with status:" status))))

(define code:define-struct-field-accessors
  ;; assumes that structname is also it's typename
  (lambda (structname fieldtype fieldname mutable?
		      #!key
		      c-field-prefix)
    (let ((c-fieldname-str (string-append
			    (or c-field-prefix "")
			    (symbol->string fieldname))))
      `(begin
	 (define ,(symbol-append structname "-" fieldname)
	   (c-lambda (,structname)
		     ,fieldtype
		     ,(string-append "___result= ___arg1->"
				     c-fieldname-str
				     ";")))
	 ,@(if mutable?
	       `((define ,(symbol-append structname "-" fieldname "-set!")
		   (c-lambda (,structname ,fieldtype)
			     void
			     ,(string-append "___arg1->"
					     c-fieldname-str
					     "=___arg2;"))))
	       '())))))

(define code:define-struct-accessors
  (lambda (#!key
	   structname
	   c-field-prefix
	   fielddefs)
    `(begin
       ,@(map (lambda (fielddef)
;		(step)
		(apply code:define-struct-field-accessors
		       (append (cons structname fielddef) ;; wird langsam ugly:  nicht mehr klar so und so viele argumente  welche ich artig wie objekte matche.
			       (list c-field-prefix: c-field-prefix))))
	      fielddefs))))

(define-macro (define-struct-field-accessors . args)
  (step)
  (apply code:define-struct-field-accessors args))

(define-macro (define-struct-accessors . args)
  ;; really difficult dsssl stufff
  (apply (lambda (structname #!key c-field-prefix )
	   (code:define-struct-accessors structname: structname
					 c-field-prefix: c-field-prefix
					 fielddefs: fielddefs))
	 args))

;;(define-macro (define-struct-accessors . args) (apply code:define-struct-accessors args))

; (define (first-two l)
;   (cons (car l)
; 	(cons (cadr l)
; 	      '())))

; (define (list-> fn)
;   (lambda (l)
;     (apply fn l)))
;;zuerst hatt ich nur ->.  list-apply auch möglich?  list-applier?wenschon?.(wennschonrichtigbleiben)
;; KRANK ist dass das bloss ein curried  apply ist REALLY.!!!eben

(define (apply/ fn)
  (lambda (l)
    (apply fn l)))

(define fielddef:fieldtype
  (apply/ (lambda (fieldtype fieldname mutable?)
	    fieldtype)))

(define code:define-struct-from-c
  (lambda (structname
	   #!key
	   c-release-function ;; string, required, is not autogenerated
	   c-field-prefix ;; string, optional
	   #!rest
	   fielddefs)
    (let ((structnamestr (symbol->string structname))
	  (arglist (map cadr fielddefs)))
      `(begin
	 (c-declare ,(flat-append-strings "
static
struct "structnamestr"*
___make_"structnamestr" () {
    struct "structnamestr" *p= calloc(1,sizeof(struct "structnamestr"));
    return p;
}"))
	 (c-define-type ,structname
			(pointer (struct ,structnamestr)
				 ,structname
				 ,(or c-release-function
				      (error "missing c-release-function keyword argument"))))
	 (define (,(symbol-append 'make- structname) ,@arglist)
	   (or ((c-lambda ,(map fielddef:fieldtype
				fielddefs)
			  ,structname
			  ,(flat-append-strings "
struct "structnamestr" *p= ___make_"structnamestr"();
___result_voidstar=p;
if (p) {
"
(map-with-iota (lambda (l n)
		 (apply
		  (lambda (fieldtype fieldname mutable?)
		    (let ((fieldnamestr (string-append
					 (or c-field-prefix "")
					 (symbol->string fieldname)))
			  (nstr (number->string n)))
		      (list
		       "    p->"fieldnamestr"=___arg"nstr";\n")))
		  l))
	       fielddefs
	       1)
"}
")) ,@arglist)
	       (error "can't allocate:" ',structname)))
	 ,(code:define-struct-accessors
c-field-prefix: c-field-prefix
structname: structname
fielddefs: fielddefs)))))


(define-macro (define-struct-from-c . args)
  (pp-through
   (apply code:define-struct-from-c args))) ;;; SHOULD i   put args into macro defs for different macro apply errors? todo

;;fe
