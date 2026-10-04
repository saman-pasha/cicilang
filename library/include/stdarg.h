/* cicilang's own <stdarg.h>: the variadic argument list as LLVM's builtins have it.
   glibc's <stdio.h> asks only for `__gnuc_va_list' (`#define __need___va_list'), as clang's header answers it. */
#ifndef __GNUC_VA_LIST
#define __GNUC_VA_LIST
typedef __builtin_va_list __gnuc_va_list;
#endif
#ifdef __need___va_list
#undef __need___va_list
#else
#ifndef _CICILANG_STDARG_H
#define _CICILANG_STDARG_H
typedef __builtin_va_list va_list;
#define va_start(ap, ...) __builtin_va_start(ap, 0)
#define va_end(ap) __builtin_va_end(ap)
#define va_arg(ap, type) __builtin_va_arg(ap, type)
#define va_copy(dest, src) __builtin_va_copy(dest, src)
#define __va_copy(dest, src) __builtin_va_copy(dest, src)
#endif
#endif
