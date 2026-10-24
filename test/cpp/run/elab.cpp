#include <cstdio>
// a block-scope struct named by its elaborated specifier after it, in two functions with one name each
int f() { struct P { int a; int b; }; struct P p = {1, 2}; P q = {3, 4}; return p.a + p.b + q.a + (int) sizeof(struct P); }
int g() { struct P { long a; }; struct P p = {5}; struct P *pp = &p; return (int) pp->a + (int) sizeof(struct P); }
int h() { union U { int i; char c[8]; }; union U u = {7}; return u.i + (int) sizeof(union U); }
int main() { std::printf("%d %d %d\n", f(), g(), h()); return 0; }
