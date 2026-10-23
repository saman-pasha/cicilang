// A static assertion in a template's body is checked in each instance (0.198): `f(5)' instantiates f<int>, whose assertion
// is false (clang++: `static assertion failed due to requirement 'sizeof(int) == 1': one byte')
template <class T> int f(T) { static_assert(sizeof(T) == 1, "one byte"); return 0; }
int main() { return f('c') + f(5); }
