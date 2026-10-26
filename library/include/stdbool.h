/* cicilang's own <stdbool.h>: C23 made bool, true and false keywords, so it defines no macro of them there, as clang's
   and gcc's headers do (C23 7.18; 0.214: `true' was C17's int 1 at C23) */
#ifndef _CICILANG_STDBOOL_H
#define _CICILANG_STDBOOL_H
#if !defined(__cplusplus) && !(defined(__STDC_VERSION__) && __STDC_VERSION__ > 201710L)
#define bool _Bool
#define true 1
#define false 0
#endif
#define __bool_true_false_are_defined 1
#endif
