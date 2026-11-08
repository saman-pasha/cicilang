#include <stdlib.h>
#include "tvector.pl"
#define DECL(t, n) t n
static inline long lsum(const vector<long> *v) { long s = 0; for (size_t i = 0; i < len(*v); i++) s += at(*v, i); return s; }
DECL(static int, hcount) = 3;
