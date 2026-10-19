// A pointer to member function keeps its cv- and ref-qualifiers (0.181): the type information's name, an overload, a
// specialization, the overloaded member a target chooses, an instance over one, a detection and a call
#include <cstdio>
#include <functional>
#include <type_traits>
#include <typeinfo>

struct A {
    int v = 5;
    int f(int k) { return v + k; }
    int cf(int k) const { return v * k; }
    int lf(int k) & { return k - v; }
    int rf(int k) && { return k * 100; }
    int clf(int k) const & { return k + 1000; }
};
struct B {
    int get() { return 1; }
    int get() const { return 2; }
};

static const char *g(int (A::*)(int)) { return "g plain"; }
static const char *g(int (A::*)(int) const) { return "g const"; }
static const char *g(int (A::*)(int) &&) { return "g rvalue"; }

template <class T> struct S { static const char *n() { return "S other"; } };
template <class R, class C> struct S<R (C::*)(int)> { static const char *n() { return "S plain"; } };
template <class R, class C> struct S<R (C::*)(int) const> { static const char *n() { return "S const"; } };
template <class R, class C> struct S<R (C::*)(int) &> { static const char *n() { return "S lvalue"; } };
template <class R, class C> struct S<R (C::*)(int) &&> { static const char *n() { return "S rvalue"; } };
template <class R, class C> struct S<R (C::*)(int) const &> { static const char *n() { return "S const lvalue"; } };

template <class T> int bump() { static int k = 0; return ++k; }

template <class T> void pf(T) { std::puts(__PRETTY_FUNCTION__); }

int main() {
    std::printf("%s %s %s %s %s\n", typeid(&A::f).name(), typeid(&A::cf).name(), typeid(&A::lf).name(), typeid(&A::rf).name(), typeid(&A::clf).name());
    std::printf("%s | %s\n", typeid(void (*)(int (A::*)(int) const, int (A::*)(int) const)).name(), typeid(void (*)(int (*)(int), int (A::*)(int))).name());
    std::printf("%s, %s, %s\n", g(&A::f), g(&A::cf), g(&A::rf));
    std::printf("%s, %s, %s, %s, %s\n", S<decltype(&A::f)>::n(), S<decltype(&A::cf)>::n(), S<decltype(&A::lf)>::n(), S<decltype(&A::rf)>::n(), S<decltype(&A::clf)>::n());
    int (B::*pc)() const = &B::get;
    int (B::*pn)() = &B::get;
    B b;
    const B cb{};
    std::printf("get: %d %d %d\n", (cb.*pc)(), (b.*pn)(), (b.*pc)());
    std::printf("bump: %d %d %d\n", bump<int (A::*)(int)>(), bump<int (A::*)(int)>(), bump<int (A::*)(int) const>());
    std::printf("invocable: %d %d %d %d %d %d %d\n",
                (int) std::is_invocable_v<int (A::*)(int), const A &, int>,
                (int) std::is_invocable_v<int (A::*)(int) const, const A &, int>,
                (int) std::is_invocable_v<int (A::*)(int) &&, A &, int>,
                (int) std::is_invocable_v<int (A::*)(int) &&, A, int>,
                (int) std::is_invocable_v<int (A::*)(int) &, A, int>,
                (int) std::is_invocable_v<int (A::*)(int) const &, A, int>,
                (int) std::is_invocable_v<int (A::*)(int) &, A &, int>);
    A a;
    const A ca{};
    std::printf("calls: %d %d %d %d %d %d\n", std::invoke(&A::f, a, 1), std::invoke(&A::cf, ca, 3), std::invoke(&A::lf, a, 9),
                std::invoke(&A::rf, A{}, 2), std::invoke(&A::clf, ca, 4), std::mem_fn(&A::cf)(ca, 6));
    int (A::*q)(int) const & = &A::clf;
    std::printf("through: %d %d\n", (ca.*q)(1), (a.*q)(2));
    pf(&A::cf);
    pf(&A::rf);
    pf(&A::clf);
    return 0;
}
