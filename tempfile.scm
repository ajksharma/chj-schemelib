;;; Copyright 2014 by Christian Jaeger <ch@christianjaeger.ch>

;;;    This file is free software; you can redistribute it and/or modify
;;;    it under the terms of the GNU General Public License (GPL) as published 
;;;    by the Free Software Foundation, either version 2 of the License, or
;;;    (at your option) any later version.


(require easy test)


(defstruct atomic-box
  constructor-name: _atomic-box
  value
  mutex)

(def (atomic-box val)
     (_atomic-box val (make-mutex)))

(def (atomic-box.update! b fn)
     (let-atomic-box ((v m) b)
		     (mutex-lock! m)
		     (with-exception-catcher
		      ;; everything is costly in this...
		      (lambda (e)
			(mutex-unlock! m)
			(raise e))
		      (& (letv ((v* res) (fn v))
			       (vector-set! b 1 v*) ;; hack
			       (mutex-unlock! m)
			       res)))))

(def. atomic-box.unbox
  atomic-box.value)

(def atomic-unbox atomic-box.value)

(TEST
 > (def b (atomic-box 1))
 > (atomic-box.update! b (lambda (v) (values (inc v) v)))
 1
 > (.value b)
 2
 > (.unbox b)
 2
 > (atomic-unbox b)
 2
 ;; XX test concurrency?..
 )

;; ---

(def random-appendices
     (delay
       (atomic-box
	(stream-map (C string.replace-substrings _ "/" "_")
		    (make-realrandom-string-stream #f)))))

(def (get-long-random-appendix)
     (atomic-box.update! (force random-appendices)
			 (lambda (s)
			   (let-pair ((str r) (force s))
				     (values r str)))))

(def (get-short-random-appendix)
     (substring (get-long-random-appendix) 0 10))


;; XX still that hack of hard-coding constants
(def (eexist-exception? v)
     (and (os-exception? v)
	  (= (os-exception-code v) -515899375)))
(def (eperm-exception? v)
     (and (os-exception? v)
	  (= (os-exception-code v) -515899379)))


(def (randomly-retrying base get-random-appendix create)
     ;; long? is a hack to work around actually non-working
     ;; EEXCL. Well, could save all the exception catching in those
     ;; cases. lol.
     (let next ((tries 10))
       ;; h the only use of retries is to make the random part in the
       ;; path shorter
       (let ((path (string-append base (get-random-appendix))))
	 (with-exception-catcher
	  (lambda (e)
	    (if (and (eexist-exception? e)
		     (positive? tries))
		(next (dec tries))
		(raise e)))
	  (& (create path)
	     path)))))


;; create-public-tmp-directory ?
;; can't make it private without using posix/ modules.
(def (public-tempdir #!key
		     #((maybe string?) perms)
		     #((maybe string?) group)
		     (base "/tmp/cgi-scm-tmp"))
     (randomly-retrying base
			get-short-random-appendix
			(lambda (path)
			  (create-directory path)
			  (if perms
			      (xxsystem "chmod" perms "--" path))
			  (if group
			      (xxsystem "chgrp" group "--" path)))))

(def tempfile-base
     ;; (string-append (getenv "HOME") "/.cgi-scm-tmp")
     (public-tempdir perms: "0770"
		     group: "www-data"))

(def (tempfile #!optional (base (string-append tempfile-base "/")))
     (randomly-retrying base
			get-long-random-appendix ;; hack
			(lambda (path)
			  (close-port (open-output-file path)))))

(def (tempfile-incremental-at base #!optional (suffix "") (z 0))
     (lambda ()
       (let lp ()
	 (let ((path
		(with-exception-catcher
		 (lambda (e)
		   (if (eexist-exception? e)
		       (begin
			 (lp))
		       (raise e)))
		 (& (let ((path (string-append base
					       (number.string z)
					       suffix)))
		      (inc! z)
		      ;; only way to exclusively create a file on Gambit?
		      (create-symbolic-link "a" path)
		      path)))))
	   (let ((tmppath (tempfile base)))
	     (rename-file tmppath path)
	     path)))))
