/* what <optional.pl>'s C text calls (0.300): abort of <stdlib.h>; and nullopt, the value of an optional that has
   none, of the type nullopt_t, as C++'s std::nullopt is. A macro file's NAME.pl.h is included with it, so a program
   includes <optional.pl> alone. */
#ifndef _CICILANG_CCLLIB_OPTIONAL_PL_H
#define _CICILANG_CCLLIB_OPTIONAL_PL_H
#include <stdlib.h>
typedef struct nullopt_t { char none; } nullopt_t;
static const nullopt_t nullopt = {0};
#endif
