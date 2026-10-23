#include <cstdio>
#include <type_traits>
#include <typeinfo>
void nf() noexcept {}
void tf() {}
int add(int a, int b) noexcept { return a + b; }
template <class F> struct Kind { static constexpr int v = 0; };
template <class R, class... A> struct Kind<R (*)(A...)> { static constexpr int v = 1; };
template <class R, class... A> struct Kind<R (*)(A...) noexcept> { static constexpr int v = 2; };
struct S { int get() const noexcept { return 7; } int put(int x) { return x; } };
int call(int (*f)(int, int) noexcept, int a) { return f(a, a); }
int main() {
    void (*p)() = nf;
    void (*q)() noexcept = nf;
    int (*pa)(int, int) noexcept = add;
    std::printf("%d %d %d %d\n", (int) noexcept(q()), (int) noexcept(p()), (int) noexcept(pa(1, 2)), (int) noexcept(tf()));
    std::printf("%d %d %d %d\n", (int) std::is_same_v<decltype(nf), void() noexcept>, (int) std::is_same_v<decltype(&nf), void (*)() noexcept>, (int) std::is_same_v<decltype(tf), void()>, (int) std::is_same_v<void() noexcept, void()>);
    std::printf("%d %d %d\n", (int) std::is_convertible_v<void (*)() noexcept, void (*)()>, (int) std::is_convertible_v<void (*)(), void (*)() noexcept>, (int) std::is_function_v<void() noexcept>);
    std::printf("%d %d %d\n", Kind<void (*)()>::v, Kind<void (*)() noexcept>::v, Kind<decltype(&add)>::v);
    std::printf("%d %d\n", (int) std::is_nothrow_invocable_v<void (*)() noexcept>, (int) std::is_invocable_v<void (*)()>);
    std::printf("%d %d %d\n", (int) std::is_same_v<decltype(&S::get), int (S::*)() const noexcept>, (int) noexcept((S{}.*(&S::get))()), (int) noexcept((S{}.*(&S::put))(1)));
    std::printf("%s %s\n", typeid(void (*)() noexcept).name(), typeid(int (S::*)() const noexcept).name());
    std::printf("%d %d\n", call(pa, 4), call(add, 5));
    p(); q();
}
