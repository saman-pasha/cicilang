/* a header of the program's own over its includer's macros and its own (0.298; ownmacros.c) */
#ifndef OWNM_BOX_H
#define OWNM_BOX_H
#include <stddef.h>
#define K 5
#include "ownm_inner.h"
#define M 24
typedef struct box { char buf[CAP]; size_t a[M]; } box;
#ifdef WIDE
typedef long num;
#else
typedef short num;
#endif
#if CAP > 10
typedef long big;
#else
typedef char big;
#endif
static int area(int s) { return SQ(s); }
static int tab[SQ(3)];
static const char *greet(void) { return GREETING; }
static size_t glen(void) { return strlen(GREETING); }
#endif
