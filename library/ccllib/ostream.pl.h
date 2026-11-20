/* what <ostream.pl>'s C text calls (phase 1d): the stdio functions, size_t and strlen, malloc for a long value's text,
   the three files, and endl and ends (1.6.3) */
#ifndef _CICILANG_CCLLIB_OSTREAM_PL_H
#define _CICILANG_CCLLIB_OSTREAM_PL_H
#include <stdio.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#ifndef _CICILANG_CCLLIB_FILE_DEFAULTS
#define _CICILANG_CCLLIB_FILE_DEFAULTS
static inline FILE *ccllib_stdout(void) { return stdout; }
static inline FILE *ccllib_stderr(void) { return stderr; }
static inline FILE *ccllib_stdin(void) { return stdin; }
static inline FILE *ccllib_file_of(long long h) { return (FILE *)(intptr_t)h; }
#endif
#ifndef _CICILANG_CCLLIB_ENDL
#define _CICILANG_CCLLIB_ENDL
/* C++'s endl and ends, values of types of their own (1.6.3): `o << endl' is the stream's write_ccllib_endl_t, which
   writes the end of a line and flushes, `o << ends' a null character */
typedef struct ccllib_endl_t { char c; } ccllib_endl_t;
typedef struct ccllib_ends_t { char c; } ccllib_ends_t;
static const ccllib_endl_t endl = { '\n' };
static const ccllib_ends_t ends = { 0 };
#endif
#endif
