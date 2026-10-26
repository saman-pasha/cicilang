/* the header of hdrdefs.c: functions and objects it defines, which are the including unit's own (C17 6.9/5) */
#ifndef HDRDEFS_H
#define HDRDEFS_H
static inline int hd_twice(int x) { return 2 * x; }
static int hd_calls;
static int hd_count(void) { return ++hd_calls; }
int hd_ext(int x);
int hd_ext(int x) { return x + hd_count(); }
inline int hd_sq(int x) { return x * x; }
static const int hd_table[] = { 3, 1, 4, 1, 5 };
int hd_global = 7;
static int hd_unused(void) { return 0; }
#endif
