// built by clang++ in the C++ gate (byval.h)
#include "byval.h"
int byval_live = 0;
int there(T t) { return t.v; }
int call_here(int x) { T b(x); return here(T(x)) + here(b); }
