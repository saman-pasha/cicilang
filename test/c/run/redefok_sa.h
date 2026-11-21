/* a header that shares a guarded helper with redefok_sb.h (1.6.7) */
#ifndef REDEFOK_SA_H
#define REDEFOK_SA_H
#ifndef REDEFOK_HELPER
#define REDEFOK_HELPER
static int helper(int a) { return a + 1; }
#endif
static int sa(int a) { return helper(a); }
#endif
