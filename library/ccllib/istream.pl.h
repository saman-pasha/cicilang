/* what <istream.pl>'s C text calls (phase 1d): the stdio functions, size_t and strlen */
#ifndef _CICILANG_CCLLIB_ISTREAM_PL_H
#define _CICILANG_CCLLIB_ISTREAM_PL_H
#include <stdio.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#ifndef _CICILANG_CCLLIB_FILE_DEFAULTS
#define _CICILANG_CCLLIB_FILE_DEFAULTS
static inline FILE *ccllib_stdout(void) { return stdout; }
static inline FILE *ccllib_stderr(void) { return stderr; }
static inline FILE *ccllib_stdin(void) { return stdin; }
static inline FILE *ccllib_file_of(long long h) { return (FILE *)(intptr_t)h; }
#endif
#endif
