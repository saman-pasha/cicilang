/* what <stringstream.pl>'s C text calls (phase 1d): stdio, stdlib and string, and size_t */
#ifndef _CICILANG_CCLLIB_STRINGSTREAM_PL_H
#define _CICILANG_CCLLIB_STRINGSTREAM_PL_H
#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
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
