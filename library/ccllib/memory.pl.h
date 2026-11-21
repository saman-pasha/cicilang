/* what <memory.pl>'s C text calls (0.309): malloc, calloc, free and abort of <stdlib.h>; and <stdint.h>, which a
   program over 1.1.3 to 1.6.4 had through this header, when a shared handle held its pool's address as a uintptr_t
   (the pool is the program's since 1.6.5, and a handle holds its slot alone) */
#ifndef _CICILANG_CCLLIB_MEMORY_PL_H
#define _CICILANG_CCLLIB_MEMORY_PL_H
#include <stdlib.h>
#include <stdint.h>
#endif
