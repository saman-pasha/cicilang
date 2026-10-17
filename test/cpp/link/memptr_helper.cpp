// built by clang++ in the C++ gate and the cross gate (memptr.h)
#include "memptr.h"
int call_cm(C *p, CM m) { return (p->*m)(); }
CM get_cm(int k) {
  switch (k) {
  case 0: return &C::va;
  case 1: return &C::na;
  case 2: return &C::vb;
  case 3: return &C::nb;
  case 4: return &C::nc;
  default: return nullptr;
  }
}
int is_null(CM m) { return m ? 0 : 1; }
