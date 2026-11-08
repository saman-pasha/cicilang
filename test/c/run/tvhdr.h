#include <stdlib.h>
#include "tvector.pl"
static inline int ivec_sum(const vector<int> *v) { int s = 0; for (size_t i = 0; i < len(*v); i++) s += at(*v, i); return s; }
