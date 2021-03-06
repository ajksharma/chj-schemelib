(require easy)

;; debugging with conts

(def *tracks* (make-table test: eq?
			  weak-keys: #t
			  weak-values: #f ;; keep cont alive as long as obj. sgh?
			  ))

;; (def tracks-keepalive-num 100)
;; (def *tracks-keepalive* (make-vector tracks-keepalive-num))

;; (def *tracks-keepalive-i* 0)

(def (T v)
     (continuation-capture
      (lambda (c)
	(table-update! *tracks* v
		       (C cons c _)
		       (C list c))
	;;(vector-set! *tracks-keepalive* *tracks-keepalive-i*  ) not so simple. need key, too, remove explicitely from table. ah and vector shouldn't keep alive. rather wills
	v)))

(def (visit v #!optional (i 0))
     (cond ((table-ref *tracks* v #f)
	    => (lambda (cs)
		 ;; XX my wrappers where?
		 (##repl-within (list-ref cs i) "" "")))
	   (else
	    (error "no continuation stored for object:" v))))

(def (noT v)
     v)
;; hmm don't confuse with naming convention of |iF|

