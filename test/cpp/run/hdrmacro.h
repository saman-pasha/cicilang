// a header of the program's own (0.268): its function uses its own function-like macro, which the read expands
#define TWICE(x) ((x) * 2)
static inline int twice_h(int x) { return TWICE(x); }
