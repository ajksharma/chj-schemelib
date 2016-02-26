(require
 (cj-env warn pp-through thunk)
 (cj-env-1 list-join)
 (srfi-1 filter-map)
 cj-inline
 char-util
 cj-env-2
 cj-c-errno_Cpart ;; from posix/ dir, local reference
 )

;; (compile #t)

;; (exports-macros
;;  ;; define-inline:
;;  check-not-posix-exception
;;  error-to-posix-exception
;;  ;; define-macro:
;;  define/check
;;  define/check->integer
 
;;  )


;; (exports-on-request
;;  strerror

;;  posix-exception-errno
;;  posix-exception-message
;;  posix-exception?
;;  posix-exception ;; "creator" but with cache
;;  ;; a way to wrap a standard message (with function name/args/values)
;;  ;; around the exception. Maybe use check-not-posix-exception instead:
;;  throw-posix-exception 
 
;;  )


;; cj 

;; Infrastructure for deadling with posix style errno based error
;; handling.

;; One cannot simply access errno *after* a call has returned to
;; scheme, since the original error will be wiped then because of
;; calls done by the scheme runtime (at least unless we switch off
;; interrupts and be very careful). So we return the error from the
;; calls, and use a special type to differentiate safely and
;; comfortably. (We cache the values to minimize gc overhead.)

(declare (block)(standard-bindings)(extended-bindings))

(define-structure posix-exception
  errno)

(define (posix-exception-message e)
  (strerror (posix-exception-errno e)))


(define %posix-exception-cache-size 128) ;; linux currently uses 0..125
(define %posix-exception-cache
  (list->vector
   (let lp ((i (- %posix-exception-cache-size 1))
	    (l '()))
     (if (< i 0)
	 l
	 (lp (- i 1)
	     (cons (make-posix-exception i)
		   l))))))
;;[maybe sometime do: allocate as permanent objects] (hm what would
;;the api look like?  (allocate type options)-alike of course? No
;;list->vector then, have to write a new set of such functions? Well:
;;or take an allocator as argument or introduce a (current-allocator),
;;or: parametrized modules?!)

(define posix-exception
  (lambda (errno)
    (if (>= errno 0)
	(if (< errno %posix-exception-cache-size)
	    (vector-ref %posix-exception-cache errno)
	    (make-posix-exception errno))
	(error "posix-exception: errno must be positive" errno))))


;; a way to wrap a standard message (with function name/args/values)
;; around the exception:

(define (throw-posix-exception v name argnames argvals)
  (error (string-append (symbol->string name)
			" "
			(object->string argnames)
			":") ;; partial evaluation would help here (does it already?)
	 argvals
	 (posix-exception-message v)))

(define (throw-posix-exception_2 v name argvals) ;; (used by my pthread module)
  (error (string-append (object->string (cons name argvals))
			":")
	 (posix-exception-message v)))
;; example:
; *** ERROR IN (stdin)@3.1 -- (pthread-attr-detachstate-set! #<pthread-attr* #2 0x82be300> 13): "Invalid argument"


(define-inline (check-not-posix-exception v name argnames argvals&)
  ;; argvals& is a thunk returning a list of the arg vals
  (if (posix-exception? v)
      (throw-posix-exception v name argnames (argvals&))
      v))
;; (todo: posix-exception? should also be inlined (but is generated by define-structure; thus really offer both a define attribute and a separate 'attributer'))

(define-macro* (define/check name name/check args . body)
  ;; make #!optional arguments work:
  (let ((args* (filter-map (lambda (v*)
			     (let ((v (source-code v*)))
			       (cond ((eq? v #!optional)
				      #f)
				     ((pair? v)
				      (car v))
				     (else
				      v*))))
			   (source-code args))))
    `(begin
       (define (,name ,@args)
	 ,@body)
       (define (,name/check ,@args)
	 (check-not-posix-exception (,name ,@args*)
				    ',name/check
				    ',args*
				    (lambda () (list ,@args*)))))))

;; 'wrapper function' to convert -errno values into posix-exception
;; values (but not throwing them):
(define-inline (error-to-posix-exception val)
  (if (and (##fixnum? val) ;; for cases where c-lambda returns scheme-object
	   (##fixnum.< val 0))
      (posix-exception (- val))
      val))


(define (string-strip-until-last-chars str chars)
  (last (string-split str (char-one-of?/ chars))))
(TEST
 > (string-strip-until-last-chars "abc:de_f:g_ha" ":_")
 "ha"
 )


;; an additional utility macro, for those cases where the return value
;; is always only an error status or an integer value:
(define-macro* (define/check->integer
		 c-name
		 name1
		 name2
		 type-argname-alist
		 returntype
		 #!key
		 nowarn)

  (or nowarn
      (string=? (source-code c-name)
		(string-strip-until-last-chars (symbol->string* name1) ":_")
		(string-strip-until-last-chars (symbol->string* name2) ":"))
      (source-warn c-name "names are not consistent"
		   (cj-desourcify name1)
		   (cj-desourcify name2)))

  (let ((type-argname-alist* (cj-desourcify type-argname-alist)))
    
    (case (source-code returntype)
      ((int uid_t gid_t
	    ssize_t ;; OK?todo.
	    )
       (let ((argnames (map cadr type-argname-alist*))
	     (argtypes (map car type-argname-alist*)))
	 ;;(newline)
	 ;;(pp-through
	 `(define/check ,name1 ,name2 ,argnames
	    (error-to-posix-exception
	     ((c-lambda ,argtypes
			,returntype
			,(string-append "___result= "
					(source-code c-name)
					"("
					(apply string-append
					       (list-join
						(map (lambda (i)
						       (string-append
							"___arg"
							(number->string i)))
						     (iota (length argnames)
							   1))
						", "))
					"); "
					"if(___result<0) ___result=-errno;"))
	      ,@argnames)))))
      (else
       (source-error returntype "unknown return type")))))
