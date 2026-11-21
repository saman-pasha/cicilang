/* a guarded header, included two times by redefok.c (1.6.7) */
#ifndef REDEFOK_G_H
#define REDEFOK_G_H
static inline int gtwice(int a) { return 2 * a; }
struct pt { int x, y; };
int gcounter = 7;
#endif
