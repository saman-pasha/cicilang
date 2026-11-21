// C++'s lvalues that an effect makes (1.6.13): a comma whose right operand is an lvalue ([expr.comma]/1), an
// assignment, a compound one too ([expr.ass]/1), and a prefix ++ or -- ([expr.pre.incr]/1). A reference bound to
// one binds the place, an assignment to one stores into it, its address is the place's, a conditional's arm may be
// one, decltype names a reference, an overload and a forwarding reference see an lvalue, and a copy constructor
// copies it. Each place is taken once: its effect is made once. Through 1.6.12 a reference bound to one took a
// temporary of its value, and the assignments to one were refused by name
#include <cstdio>
#include <type_traits>
#include <utility>

int cnt = 0;
int g() { return 0; }
int next() { return cnt++; }
int a = 1, b = 2;
struct S { int m; int bf : 4; } s{3, 1};
int &h() { return (g(), b); }
int &hb() { return b; }
int &f2(int &x) { return x = 5; }
void f(int &x) { x = 40; }
void ov(int &) { std::printf(" lvalue"); }
void ov(int &&) { std::printf(" rvalue"); }
template<class T> int fw(T &&) { return (int)std::is_lvalue_reference<T>::value; }
struct C { int v; C(int x) : v(x) {} C(const C &o) : v(o.v + 100) {} };

int main(int argc, char **) {
    { int &r = (g(), b); r = 9; std::printf("comma bound: %d %d\n", a, b); }
    { int &r = argc > 0 ? a : (g(), b); r = 7; std::printf("conditional arm: %d %d\n", a, b); }
    { (g(), b) = 5; std::printf("comma assigned: %d %d\n", a, b); }
    { int &r = (a = 5); r = 6; std::printf("assignment bound: %d %d\n", a, b); }
    { int &r = ++a; r = 8; std::printf("prefix ++ bound: %d\n", a); }
    { int &r = --a; r = 14; std::printf("prefix -- bound: %d\n", a); }
    { int &r = (a += 2); r = 30; std::printf("compound bound: %d\n", a); }
    { (a = 1) = 2; std::printf("assignment assigned: %d\n", a); }
    { ++(++a); std::printf("prefix ++ stepped: %d\n", a); }
    { (a += 2) = 21; std::printf("compound assigned: %d\n", a); }
    { int &r = (g(), (g(), b)); r = 11; std::printf("nested comma: %d\n", b); }
    { int &r = (a, b, a); r = 41; std::printf("three operands: %d %d\n", a, b); }
    { f((g(), b)); std::printf("reference parameter: %d\n", b); }
    { auto &r = (g(), b); r = 12; std::printf("auto &: %d\n", b); }
    { auto &&r = (g(), b); r = 38; std::printf("auto &&: %d\n", b); }
    { (g(), s.m) = 4; std::printf("member: %d\n", s.m); }
    { int &r = (s.m = 7); r = 8; std::printf("member assigned, bound: %d\n", s.m); }
    { h() = 13; std::printf("returned comma: %d\n", b); }
    { f2(a) = 6; std::printf("returned assignment: %d\n", a); }
    { int &r = (g(), hb()); r = 37; std::printf("comma over a call: %d\n", b); }
    { int *p = &(g(), b); *p = 15; std::printf("address of comma: %d\n", b); }
    { int *p = &(a = 5); *p = 39; std::printf("address of assignment: %d\n", a); }
    { int *p = &++a; *p = 40; std::printf("address of prefix ++: %d\n", a); }
    { (g(), a) += 3; std::printf("compound over comma: %d\n", a); }
    { decltype((g(), b)) r = b; r = 16; std::printf("decltype((comma)): %d\n", b); }
    { decltype(g(), b) r = a; r = 35; std::printf("decltype(comma): %d\n", a); }
    { decltype(a = 5) r = b; r = 33; std::printf("decltype(assignment): %d %d\n", a, b); }
    { decltype(++a) r = b; r = 34; std::printf("decltype(prefix ++): %d %d\n", a, b); }
    { int &r = ((argc > 0 ? a : b) = 17); r = 18; std::printf("conditional assigned: %d %d %d\n", a, b, r); }
    { int i = 0; int arr[3] = {0, 0, 0}; int &r = (arr[i++] = 5); r = 19; std::printf("index stepped once: %d %d %d\n", arr[0], arr[1], i); }
    { int i = 0; int arr[2] = {0, 0}; int &r = ++arr[i++]; r = 42; std::printf("prefix ++ of an index: %d %d %d\n", arr[0], arr[1], i); }
    { int i = 0; int arr[2] = {5, 6}; (arr[i++] += 1) = 43; std::printf("compound of an index: %d %d %d\n", arr[0], arr[1], i); }
    { const int &r = (g(), b); b = 20; std::printf("const reference: %d %d\n", r, b); }
    { const int &r = (s.bf = 5); s.bf = 6; std::printf("bit-field's value: %d %d\n", r, (int)s.bf); }
    { int arr[3] = {1, 2, 3}; int *p = arr; int *&q = (p += 1); q += 1; std::printf("pointer stepped, bound: %d %d\n", (int)(p - arr), *p); }
    { int arr[3] = {0, 0, 0}; for (int &x : (g(), arr)) x = 1; std::printf("range over comma: %d %d %d\n", arr[0], arr[1], arr[2]); }
    { int &&rr = std::move((g(), b)); rr = 36; std::printf("moved comma: %d\n", b); }
    { int x = std::move(next() == 0 ? a : b); std::printf("moved conditional: %d %d\n", x, cnt); }
    { std::printf("overloads:"); ov((g(), b)); ov(a = 1); ov(++a); ov(a++); ov((g(), 5)); std::printf("\n"); }
    { std::printf("forwarded: %d %d %d %d\n", fw((g(), b)), fw(a = 1), fw(++a), fw(a++)); }
    { C c1(1); C c2 = (g(), c1); std::printf("copy constructor: %d\n", c2.v); }
    { int x = 1; int *q = &(g(), x); int &r = (x = 4); *q = 5; std::printf("local borrows: %d %d\n", x, r); }
    { int x = 1; int y = (x = 4) + 1; int z = ++x * 2; std::printf("values still: %d %d %d\n", x, y, z); }
    return 0;
}
