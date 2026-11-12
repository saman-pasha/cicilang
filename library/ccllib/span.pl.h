/* <span.pl>'s header (0.295): what its C text calls -- abort of <stdlib.h> -- and std::span's `dynamic_extent', the
   count that subspan takes for every element after the offset. A macro file's NAME.pl.h is included with it, so a
   program includes <span.pl> alone. */
#ifndef _CICILANG_CCLLIB_SPAN_PL_H
#define _CICILANG_CCLLIB_SPAN_PL_H
#include <stdlib.h>
static const size_t dynamic_extent = (size_t)-1;
#endif
