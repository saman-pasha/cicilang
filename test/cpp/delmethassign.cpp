struct R { int &r; };
struct S { R a; S(R x) : a(x) {} void set(const R &y) { a = y; } };
int main() { int v = 1, w = 2; S s(R{v}); s.set(R{w}); return s.a.r; }
