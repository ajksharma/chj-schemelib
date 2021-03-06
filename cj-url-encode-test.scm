(require easy
	 cj-url-encode
	 random
	 test)

(def (cj-url-encode-test n len)
     (repeat n (let* ((s (random-string len))
		      (s* (url-encode s)))
		 (assert (>= (string-length s*) len))
		 (assert (string=? (url-decode s*) s)))))

(TEST
 > (cj-url-encode-test 100 1)
 > (cj-url-encode-test 10 4)
 > (cj-url-encode-test 10 40))


(def (cj-url-encode-bench n len)
     (repeat n (=> (random-string len)
		   url-encode)))

