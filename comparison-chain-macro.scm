(require easy)

(export comparison-chain-<-expand
	comparison-chain-<=-expand)


(def (a->b-fieldnames fieldnames)
     (map gensym fieldnames))

(def (comparison-chain-<-expand a-fieldnames b-fieldnames)
     (let-pair
      ((a-fieldname a-fieldnames*) a-fieldnames)
      (let-pair
       ((b-fieldname b-fieldnames*) b-fieldnames)

       (let ((end `(< ,a-fieldname ,b-fieldname)))
	 (if (null? (rest a-fieldnames))
	     end
	     `(or ,end
		  (and (= ,a-fieldname ,b-fieldname)
		       ,(comparison-chain-<-expand a-fieldnames*
						   b-fieldnames*))))))))

(def (comparison-chain-<=-expand a-fieldnames b-fieldnames)
     (let-pair
      ((a-fieldname a-fieldnames*) a-fieldnames)
      (let-pair
       ((b-fieldname b-fieldnames*) b-fieldnames)

       (if (null? (rest a-fieldnames))
	   `(<= ,a-fieldname ,b-fieldname)
	   `(or (< ,a-fieldname ,b-fieldname)
		(and (= ,a-fieldname ,b-fieldname)
		     ,(comparison-chain-<=-expand a-fieldnames*
						  b-fieldnames*)))))))

(TEST
 > (def fns (reverse '(sec
		       min
		       hour
		       mday
		       month-1
		       year-1900)))
 > (def b-fns (map (lambda (fn)
		     (symbol-append "b-" fn))
		   fns))
 > (comparison-chain-<-expand fns b-fns)
 (or (< year-1900 b-year-1900)
     (and (= year-1900 b-year-1900)
	  (or (< month-1 b-month-1)
	      (and (= month-1 b-month-1)
		   (or (< mday b-mday)
		       (and (= mday b-mday)
			    (or (< hour b-hour)
				(and (= hour b-hour)
				     (or (< min b-min)
					 (and (= min b-min)
					      (< sec b-sec)))))))))))

 > (comparison-chain-<=-expand fns b-fns)
 (or (< year-1900 b-year-1900)
     (and (= year-1900 b-year-1900)
	  (or (< month-1 b-month-1)
	      (and (= month-1 b-month-1)
		   (or (< mday b-mday)
		       (and (= mday b-mday)
			    (or (< hour b-hour)
				(and (= hour b-hour)
				     (or (< min b-min)
					 (and (= min b-min)
					      (<= sec b-sec))))))))))))


