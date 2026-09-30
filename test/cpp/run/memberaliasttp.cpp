// A member alias template handed as a template template argument, `Tester::template Apply' -- how libc++'s
// iterator concept is chosen (_ITER_CONCEPT through _Tester::template _Apply).
#include <cstdio>
template <class A, class B> struct same { static constexpr int v = 0; };
template <class A> struct same<A, A> { static constexpr int v = 1; };
struct T1 { template <class I> using Apply = typename I::kind; };
struct T2 { template <class I> using Apply = I *; };
struct T3 : T1 {};
template <template <class> class F, class X> struct use { using type = F<X>; };
template <class Tester, class I> struct test { using type = typename use<Tester::template Apply, I>::type; };
struct It { using kind = long; };
int main() {
    std::printf("%d %d %d\n", same<test<T1, It>::type, long>::v, same<test<T2, It>::type, It *>::v, same<test<T3, It>::type, long>::v);
    return 0;
}
