;;; Copyright 2013 by Christian Jaeger <ch@christianjaeger.ch>

;;;    This file is free software; you can redistribute it and/or modify
;;;    it under the terms of the GNU General Public License (GPL) as published 
;;;    by the Free Software Foundation, either version 2 of the License, or
;;;    (at your option) any later version.


(require cj-functional
	 cj-ffi
	 ;;cj-env-2
	 )

(include "../cj-standarddeclares.scm")


(c-declare "
#include <sys/mman.h>

#define VOID2FIX(e) ___CAST(___WORD,(e))
#define FIX2VOID(e) ___CAST(void*,(e))

int mmap_errno=0;
#include <string.h> // strerror
#include <errno.h> // errno

")

(define void*? fixnum?)

(define-typed (posix:_mmap
	       #((maybe void*?) addr) ;; addr not yet implemented
	       #(size? length)
	       #(size0? prot)	     ;; int
	       #(size0? flags)	     ;; int
	       #(size0? fd)	     ;; int
	       ;; XX what is off_t?:
	       #(size0? offset))
  ;; returns 0 instead of -1 on errors
  (##c-code "
void* addr= FIX2VOID(___ARG1);
size_t length= ___INT(___ARG2);
int prot= ___INT(___ARG3);
int flags= ___INT(___ARG4);
int fd= ___INT(___ARG5);
off_t offset= ___INT(___ARG6);

void* res= mmap(addr, length, prot, flags, fd, offset);
mmap_errno= errno;
___RESULT= (___CAST(___WORD,res) == -1) ? ___FIX(0) : VOID2FIX(res);
" (or addr 0) length prot flags fd offset))

(define mmap:error
  (c-lambda ()
	    char-string
	    "___result= strerror(mmap_errno);"))

(define (posix:mmap maybe-addr length prot flags fd offset)
  (let ((res (posix:_mmap maybe-addr length prot flags fd offset)))
    (if (zero? res)
	(error "mmap:" (mmap:error))
	res)))


(define-constants-from-C PROT_EXEC PROT_READ PROT_WRITE PROT_NONE)

(define-constants-from-C MAP_SHARED MAP_PRIVATE)

(define-typed (posix:_munmap #(void*? addr)
		       #(size? length))
  (##c-code "
void* addr= FIX2VOID(___ARG1);
size_t length= ___INT(___ARG2);

___RESULT= ___FIX(munmap(addr,length));
mmap_errno= errno;"
	    addr length))

(define (posix:munmap addr length)
  (or (zero? (posix:_munmap addr length))
      (error "unmap:" (mmap:error))))

