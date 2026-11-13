/* what <variant.pl>'s C text calls (0.308): abort and size_t of <stdlib.h>; and monostate, the alternative of no
   value, as C++'s std::monostate is. A macro file's NAME.pl.h is included with it, so a program includes <variant.pl>
   alone. */
#ifndef _CICILANG_CCLLIB_VARIANT_PL_H
#define _CICILANG_CCLLIB_VARIANT_PL_H
#include <stdlib.h>
typedef struct monostate { char none; } monostate;
#endif
