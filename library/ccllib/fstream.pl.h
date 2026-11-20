/* what <fstream.pl>'s C text calls (phase 1d), and the names of C++'s <fstream> */
#ifndef _CICILANG_CCLLIB_FSTREAM_PL_H
#define _CICILANG_CCLLIB_FSTREAM_PL_H
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
static inline long long ccllib_file_open(const char *p, const char *m) { return (long long)(intptr_t)fopen(p, m); }
static inline void ccllib_file_close(long long h) { if (h) fclose((FILE *)(intptr_t)h); }
#define ofstream fstream
#define ifstream fstream
#endif
