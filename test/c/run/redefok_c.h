/* a guarded header with a conditional past its guard, included two times by redefok.c (1.6.7) */
#ifndef REDEFOK_C_H
#define REDEFOK_C_H
#ifdef REDEFOK_WIDE
static long width(void) { return 64; }
#else
static int width(void) { return 32; }
#endif
#endif
