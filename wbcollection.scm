;;; Copyright 2014-2016 by Christian Jaeger <ch@christianjaeger.ch>

;;;    This file is free software; you can redistribute it and/or modify
;;;    it under the terms of the GNU General Public License (GPL) as published 
;;;    by the Free Software Foundation, either version 2 of the License, or
;;;    (at your option) any later version.


(require easy
	 (cj-source-quasiquote quasiquote-source)
	 (wbtree wbtree? _wbtree? empty-wbtree empty-wbtree?
		 wbtreeparameter*))

(export (class wbcollection)
	empty-wbcollection
	list.wbcollection
	(methods size
		 contains?
		 min
		 max
		 add
		 delete
		 members list
		 members-stream stream
		 union
		 difference
		 intersection
		 intersection-stream
		 rank
		 index))


(defmacro (def-wbcollection-method name+args . body)
  (match* name+args
	  ((name c . args)
	   (quasiquote-source
	    (method ,name+args
		    (let-wbcollection
		     (($wbtreeparameter $data) ,c)
		     ,@body))))))


(class wbcollection
       (struct #(wbtreeparameter? param)
	       #(wbtree? data))

       ;; (Methods which take an item can't type-check it: we don't
       ;; have a type predicate, just a comparison function. The type
       ;; predicate in wbtreeparameter? is only used by wbtree.scm to
       ;; distinguish leafs from branches.)

       (def-wbcollection-method (size c)
	 (wbtree:size $data))

       (def-wbcollection-method (empty? c)
	 (empty-wbtree? $data))

       (def-wbcollection-method (contains? c item)
	 (wbtree:member? $data item))

       ;; (def-wbcollection-method ( c)
       ;; 	 (wbtree:maybe-ref $data))

       ;; (def-wbcollection-method ( c)
       ;; 	 (wbtree:maybe-ref&rank $data))

       (def-wbcollection-method (min c)
	 (wbtree:min $data))

       (def-wbcollection-method (max c)
	 (wbtree:max $data))

       ;; `first` and `rest` don't really seem fitting here, since
       ;; there's no maintainance of insertion order, so leave it to
       ;; min and max.

       ;; XX is there a faster way to do this? (splitting)
       (def-wbcollection-method (min&rest c)
	 (let ((*v (wbtree:min $data)))
	   (values *v
		   (wbcollection $wbtreeparameter
				 (wbtree:delete $data *v)))))
       ;; copy-paste
       (def-wbcollection-method (max&rest c)
	 (let ((*v (wbtree:max $data)))
	   (values *v
		   (wbcollection $wbtreeparameter
				 (wbtree:delete $data *v)))))

       (def-wbcollection-method (add c item)
	 (wbcollection $wbtreeparameter
		       (wbtree:add $data item)))

       (def-wbcollection-method (delete c item)
	 (wbcollection $wbtreeparameter
		       (wbtree:delete $data item)))

       ;; wbtree:inorder-fold
       ;; wbtree:stream-inorder-fold
       ;; wbtree:inorder-fold-reverse
       ;; wbtree:stream-inorder-fold-reverse

       (def-wbcollection-method (members c)
	 (wbtree:members $data))

       (method list wbcollection.members)

       (def-wbcollection-method (members-stream c)
	 (wbtree:stream-members $data))

       (method stream wbcollection.members-stream)

       ;; wbtree:lt
       ;; wbtree:gt
       ;; wbtree:next

       (def-wbcollection-method (union c1 c2)
	 (wbtree:union $data c1 c2))

       (def-wbcollection-method (difference c)
	 (wbtree:difference $data))

       (def-wbcollection-method (intersection c1 c2)
	 (wbtree:intersection $data c1 c2))

       (def-wbcollection-method (intersection-stream c1 c2)
	 (wbtrees:intersection-stream $data c1 c2))

       ;; wbtree->stream
       ;; wbtree:between

       (def-wbcollection-method (rank c item)
	 (wbtree:rank $data item))

       ;; rename this to `.ref` ? Or would that be dangerously close
       ;; to `.contains?` ?
       (def-wbcollection-method (index c item)
	 (wbtree:index $data item)))


(def (empty-wbcollection #(function? cmp))
     (wbcollection (wbtreeparameter* cmp)
		   empty-wbtree))

(def (list.wbcollection #(function? cmp)
			l)
     (let (($wbtreeparameter (wbtreeparameter* cmp)))
       (wbcollection $wbtreeparameter
		     (list->wbtree l))))


(TEST
 ;; make sure there's no confusion with wbtee symbols
 > (def c (list.wbcollection generic-cmp '(1 9 -2 wbtree #(wbtree))))
 > (.list c)
 (-2 1 9 wbtree #(wbtree))
 > (def c (list.wbcollection generic-cmp '(1 9 -2 wbtree #(wbtree 1 2 3 4))))
 > (.list c)
 (-2 1 9 wbtree #(wbtree 1 2 3 4)))


(TEST
 > (def c (list.wbcollection number-cmp '(1 3 2 9 -2 3.3 3)))
 > (.contains? c 3)
 #t
 > (.contains? c 3.3)
 #t
 > (.contains? c 3.5)
 #f
 > (.list c)
 (-2 1 2 3 3.3 9)
 > (.min c)
 -2
 > (.max c)
 9
 > (def c2 (.add c 12))
 > (.max c2)
 12
 > (.max c)
 9
 > (.contains? (.delete c2 3) 3)
 #f
 > (map (C .rank c _) '(-2 1 2 3 3.3 9))
 (0 1 2 3 4 5)
 > (.rank c2 12)
 6
 > (with-exception-catcher identity (& (.rank c 12)))
 not-found ;; perhaps todo: also add .Maybe-rank

 ;; site and emptyness:
 > (def c (list.wbcollection number-cmp '(1 9)))
 > (.size c)
 2
 > (.empty? c)
 #f
 > (set! c (.delete c 1))
 > (.empty? c)
 #f
 > (.contains? c 9)
 #t
 > (.size c)
 1
 > (.min c)
 9
 > (.max c)
 9
 > (defvalues (m r) (.min&rest c2))
 > m
 -2
 > (.list r)
 (1 2 3 3.3 9 12)
 > (defvalues (m r) (.max&rest c2))
 > m
 12
 > (.list r)
 (-2 1 2 3 3.3 9)
 
 ;; > (with-exception-catcher identity (& (set! c (.delete c 1))))
 ;; not-found  XXX why does this give #!void instead of exception?
 > (set! c (.delete c 9))
 > (.empty? c)
 #t
 > (.contains? c 9)
 #f
 > (.size c)
 0
 > (%try-error (.min c))
 ;; sigh, why different kind of error here?
 #(error "can't get min from empty wbtree")
 > (%try-error (.max c))
 #(error "can't get min from empty wbtree"))
