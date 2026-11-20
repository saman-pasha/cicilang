// C++'s unary + ([expr.unary.op]/7, [over.match.oper]/2, [over.built]/9): a class's own operator, a free one, a scoped
// enum's, a conversion to an arithmetic type, a template's operand, a pointer, an array, a function, and a char's
// promotion choosing an overload, and a free unary operator that does not take the operand, beside the built-in one
// over a conversion; through 1.6.0 the form was its operand, so `+v' gave v itself with no word, a free
// operator+ was never called, and `int *q = +p;' was refused, `plain pointer not consumed'
#include <cstdio>
struct V { int x; V operator+() const { return V{x + 100}; } V operator-() const { return V{-x}; } };
struct W { int x; };
W operator+(W w) { return W{w.x + 7}; }
W operator-(W w) { return W{-w.x}; }
struct M { operator double() const { return 2.5; } };
enum class E { a = 3 };
int operator+(E e) { return (int)e * 10; }
template <class T> T plus(T t) { return +t; }
static int twice(int x) { return 2 * x; }
static int f(int) { return 1; }
static int f(char) { return 2; }
int main() {
    V v{5};
    V a = +v, b = -v;
    W w{1};
    W c = +w;
    double d = +M{}, e = -M{};
    W n = -w;
    int x = 4, *p = &x, *q = +p;
    int arr[3] = {7, 8, 9};
    int *r = +arr;
    char ch = 'A';
    int (*h)(int) = +twice;
    std::printf("%d %d %d %.1f %d %d %d %d %d\n", a.x, b.x, c.x, d, +E::a, *q, r[1], (int)sizeof(+ch), plus(v).x);
    std::printf("%d %d %d %.1f %d\n", h(4), f(+ch), f(ch), e, n.x);
    return 0;
}
