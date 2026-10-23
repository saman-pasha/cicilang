// C++20's template parameter objects: a class template deduced from a string literal, its address the same for one value, a member function called, a parameter handed on, a class instance keyed by the value
#include <cstdio>
#include <cstddef>
#include <type_traits>
struct Pt { int x, y; constexpr int sum() const { return x + y; } };
template <std::size_t N> struct Str {
    char s[N];
    constexpr Str(const char (&a)[N]) { for (std::size_t i = 0; i < N; i++) s[i] = a[i]; }
    constexpr std::size_t size() const { return N - 1; }
};
template <Str S> const char *name() { return S.s; }
template <Str S> const char *outer() { return name<S>(); }
template <Str S> const void *where() { return &S; }
template <Pt P> int psum() { return P.sum(); }
template <Pt P> struct T2 { static constexpr int k = P.sum(); };
template <Str S> std::size_t len() { return S.size(); }
int main() {
    std::printf("%s %s %zu %zu\n", outer<"abc">(), name<"abc">(), len<"hello">(), len<"">());
    std::printf("%d %d %d\n", (int) (where<"abc">() == where<"abc">()), (int) (where<"abc">() == where<"abd">()), (int) (where<"abc">() != nullptr));
    std::printf("%d %d\n", psum<Pt{5, 6}>(), T2<Pt{2, 3}>::k);
    std::printf("%d %d\n", (int) std::is_same_v<T2<Pt{1, 2}>, T2<Pt{1, 2}>>, (int) std::is_same_v<T2<Pt{1, 2}>, T2<Pt{1, 3}>>);
}
