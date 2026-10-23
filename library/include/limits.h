/* cicilang's own <limits.h>, the freestanding one C requires of the compiler (LP64 targets):
   the values are the predefined macros' (__INT_MAX__ and kin, the reference compiler's), and
   the C library's own limits.h follows through #include_next where there is one -- glibc's
   defines nothing of these itself under a GNU-shaped compiler and asks the compiler's header
   for them (it tests _GCC_LIMITS_H_, which GCC's file defines and this one does too), so on
   Linux INT_MAX was undefined until this header existed; the SDK's on macOS defines them all
   itself, and a redefinition to the same value is nothing. */
#ifndef _CICILANG_LIMITS_H
#define _CICILANG_LIMITS_H
#define _GCC_LIMITS_H_

#define CHAR_BIT __CHAR_BIT__
#define SCHAR_MAX __SCHAR_MAX__
#define SCHAR_MIN (-__SCHAR_MAX__ - 1)
#define UCHAR_MAX (__SCHAR_MAX__ * 2 + 1)
#ifdef __CHAR_UNSIGNED__
#define CHAR_MIN 0
#define CHAR_MAX UCHAR_MAX
#else
#define CHAR_MIN SCHAR_MIN
#define CHAR_MAX SCHAR_MAX
#endif
#define SHRT_MAX __SHRT_MAX__
#define SHRT_MIN (-__SHRT_MAX__ - 1)
#define USHRT_MAX (__SHRT_MAX__ * 2 + 1)
#define INT_MAX __INT_MAX__
#define INT_MIN (-__INT_MAX__ - 1)
#define UINT_MAX (__INT_MAX__ * 2U + 1U)
#define LONG_MAX __LONG_MAX__
#define LONG_MIN (-__LONG_MAX__ - 1L)
#define ULONG_MAX (__LONG_MAX__ * 2UL + 1UL)
#define LLONG_MAX __LONG_LONG_MAX__
#define LLONG_MIN (-__LONG_LONG_MAX__ - 1LL)
#define ULLONG_MAX (__LONG_LONG_MAX__ * 2ULL + 1ULL)
#ifndef MB_LEN_MAX
#define MB_LEN_MAX 16
#endif

/* C23: the widths ([tab:limits.h]), and the bit-precise integers' bound */
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L
#define __STDC_VERSION_LIMITS_H__ 202311L
#define BOOL_WIDTH __BOOL_WIDTH__
#define CHAR_WIDTH CHAR_BIT
#define SCHAR_WIDTH CHAR_BIT
#define UCHAR_WIDTH CHAR_BIT
#define SHRT_WIDTH __SHRT_WIDTH__
#define USHRT_WIDTH __SHRT_WIDTH__
#define INT_WIDTH __INT_WIDTH__
#define UINT_WIDTH __INT_WIDTH__
#define LONG_WIDTH __LONG_WIDTH__
#define ULONG_WIDTH __LONG_WIDTH__
#define LLONG_WIDTH __LLONG_WIDTH__
#define ULLONG_WIDTH __LLONG_WIDTH__
#define BITINT_MAXWIDTH __BITINT_MAXWIDTH__
#endif

/* the C library's own (PATH_MAX and POSIX's, on the platforms that have them), past this file */
#if __has_include_next(<limits.h>)
#include_next <limits.h>
#endif
#endif
