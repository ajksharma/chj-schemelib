(require)

(include "../cj-standarddeclares.scm")


; (declare (fixnum)
; 	 (not safe))

(c-declare "
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>

static const size_t buflen= 1024;
static ___UTF_8STRING buf = NULL;
")

(define strerror
  (c-lambda (int)
	    UTF-8-string
	    "
if (!buf) {
    buf= ___CAST(___UTF_8STRING, malloc(buflen));
    /* XX let it segfault if malloc fails? */
}

#if (_POSIX_C_SOURCE >= 200112L || _XOPEN_SOURCE >= 600) && ! _GNU_SOURCE
    strerror_r(___arg1, buf, buflen);
    ___result= buf;
#else
    ___result= strerror_r(___arg1, buf, buflen);
#endif
"))

