// A free operator is taken only where its parameters take the operands ([over.match.viable]/3): a binary one as a
// unary one, an operand by a converting constructor of the parameter's class, else the built-in operator (1.6.6)
#include <cstdio>
struct W1 { int x; };
W1 operator-(W1 w) { return W1{-w.x}; }
W1 operator*(W1 a, W1 b) { return W1{a.x * b.x}; }
struct M1 { operator double() const { return 2.5; } };
struct V { int x; V(int a) : x(a) {} };
V operator+(V a, V b) { return V(a.x + b.x); }
bool operator==(const V &a, const V &b) { return a.x == b.x; }
struct X { int y; };
struct Y { int z; Y(X x) : z(x.y * 10) {} };
int operator%(const Y &a, int b) { return a.z % b; }
struct B { int v; };
struct D : B { int w; };
int operator^(const B &a, const B &b) { return a.v * b.v; }
struct T { int q; operator B() const { return B{q}; } };
struct K { int k; K operator-(int n) const { return K{k - n}; } };
K operator-(K a, K b) { return K{a.k * 100 + b.k}; }
struct W2 { int x; };
W2 operator/(W2 a, int n) { return W2{a.x / n}; }
struct M2 { operator double() const { return 2.5; } };
bool operator<(const W2 &a, const W2 &b) { return a.x < b.x; }
struct A { int v; };
A &operator+=(A &a, const A &b) { a.v += b.v; return a; }
struct N { operator int() const { return 4; } };
struct M3 { int m; };
struct W3 { int x; W3(M3 a) : x(a.m) {} };
int operator~(W3 w) { return -w.x; }
struct In { int n; };
In &operator>>(In &i, char &c) { c = 'Q'; i.n++; return i; }
In &operator>>(In &i, unsigned char &c) { return i >> (char &)c; }
int main() {
    double d = -M1{}, e = M1{} * 2.0, e2 = 2.0 * M1{}, e3 = M1{} * M1{};
    W1 w{3};
    W1 f = -w, g = w * w;
    std::printf("class and conversion: %.1f %.1f %.2f %.2f %d %d\n", d, e, e2, e3, f.x, g.x);
    V a = V(1) + 2, b = 3 + V(4);
    bool c = V(5) == 5, c2 = 6 == V(6), c3 = V(1) == 2;
    int r = X{7} % 4;
    std::printf("converting constructors: %d %d %d %d %d %d\n", a.x, b.x, c, c2, c3, r);
    D dd; dd.v = 6; dd.w = 0;
    B bb{7};
    K k{1};
    std::printf("derived, conversion to the class, member: %d %d %d %d\n", dd ^ bb, T{3} ^ bb, (k - 2).k, (k - K{5}).k);
    W2 w2{6};
    std::printf("standard conversion, built-in: %d %d %d\n", (w2 / 2.9).x, M2{} < 3.0, 2.0 < M2{});
    A aa{1};
    aa += A{2};
    int i = 10;
    i += N{};
    std::printf("compound assignment: %d %d\n", aa.v, i);
    std::printf("unary by a converting constructor: %d\n", ~M3{5});
    In in{0};
    unsigned char uc = 0;
    in >> uc;
    std::printf("a C-style cast to a reference, an lvalue: %c %d\n", uc, in.n);
    return 0;
}
