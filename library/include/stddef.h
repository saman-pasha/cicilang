/* cicilang's own <stddef.h>, for LP64 targets: the compiler's header, not a library's */
#ifndef _CICILANG_STDDEF_H
#define _CICILANG_STDDEF_H
typedef unsigned long size_t;
typedef long ptrdiff_t;
#ifndef __cplusplus
typedef int wchar_t;
#endif
typedef long double max_align_t;
#define NULL ((void *)0)
#define offsetof(t, m) __builtin_offsetof(t, m)
/* C23: nullptr's own type, and unreachable() -- the store keys a C23 read apart from the C17 one */
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L
typedef typeof(nullptr) nullptr_t;
#define unreachable() __builtin_unreachable()
#define __STDC_VERSION_STDDEF_H__ 202311L
#endif
#endif
/* A request of one piece (glibc's `#define __need_size_t' before `#include <stddef.h>') is answered by the whole header
   and cleared on every inclusion, as clang's header clears it (0.179): left defined, it made every later inclusion one
   more request, and libc++'s <stddef.h> answers a request by `#include_next' alone -- so at C++23, whose headers include
   <cstddef> after a C header, ::nullptr_t was never declared and <cstddef> stopped at its #error. */
#undef __need_ptrdiff_t
#undef __need_size_t
#undef __need_rsize_t
#undef __need_wchar_t
#undef __need_NULL
#undef __need_nullptr_t
#undef __need_unreachable
#undef __need_max_align_t
#undef __need_offsetof
#undef __need_wint_t
