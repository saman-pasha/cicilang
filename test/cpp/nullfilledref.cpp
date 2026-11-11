// A NULL OWN FIELD THAT A CALL MAY FILL IS LIVE AFTER IT, IN C++ TOO (0.272): fill takes the struct by a reference that
// is not const and may put a buffer where the field was null, so s owns one after the call, and the return leaks it
typedef unsigned long size_t;
extern "C" { void *malloc(size_t) noexcept; void free(void *) noexcept; }
struct Slot { own int *d; };
void fill(Slot &s) noexcept { if (!s.d) s.d = (own int *) malloc(sizeof(int)); }
int main() { Slot s = { nullptr }; fill(s); return 0; }
