// a header of the program's own that reads only through the preprocessor (0.268): an object declared through its own
// macro; its functions are the program's, each defined once
#define DECL(t, n) t n
static inline int thrice_h(int x) { return 3 * x; }
int plain_h(int x) { return x + 1; }
DECL(static int, hcount) = 3;
