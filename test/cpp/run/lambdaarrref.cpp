// A CAPTURE BY REFERENCE REFERS TO THE ENTITY'S OWN TYPE ([expr.prim.lambda.capture]/12; 0.227): a reference to an array stays one
// in the closure, so `std::forward<A>(a)' of it in the body is the array -- libc++ 22's emplace_back passes its arguments through
// such a lambda --, and a captured array keeps its size; a string literal binds a reference member to an array directly
// ([dcl.init.ref]/5.1), and a captured const stays const
#include <cstdio>
#include <cstring>
#include <utility>
void take(const char *s) { std::printf("%s %d\n", s, (int) std::strlen(s)); }
template <class... A> void via(A &&...a) {
    auto f = [&] { take(std::forward<A>(a)...); };
    f();
}
template <class A> void via1(A &&a) {
    auto f = [&a] { take(static_cast<A &&>(a)); };
    f();
}
template <class A> int size_in(A &&a) {
    auto f = [&] { return (int) sizeof(a); };
    return f();
}
struct H { const char (&r)[4]; };
int main() {
    via("hello");
    via1("world");
    char buf[12] = "local";
    auto g = [&] { buf[0] = 'L'; return (int) sizeof(buf); };
    int n = g();
    std::printf("%d %s %d\n", n, buf, size_in("abcdef"));
    H h{"abc"};
    take(static_cast<const char (&)[4]>(h.r));
    const int c = 7;
    auto k = [&c] { return c * 2; };
    std::printf("%d\n", k());
    return 0;
}
