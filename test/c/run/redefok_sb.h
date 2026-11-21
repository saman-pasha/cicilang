/* a header that shares a guarded helper with redefok_sa.h (1.6.7) */
#ifndef REDEFOK_SB_H
#define REDEFOK_SB_H
#ifndef REDEFOK_HELPER
#define REDEFOK_HELPER
static int helper(int a) { return a + 1; }
#endif
static int sb(int a) { return helper(a) * 2; }
#endif
