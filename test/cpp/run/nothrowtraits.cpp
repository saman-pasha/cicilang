// The nothrow traits answer the declarations (0.193), and libc++'s exceptions configuration asks them in
// std::move_if_noexcept: a vector grows by moving an element whose move constructor is noexcept, and by copying
// one whose move constructor may throw
#include <cstdio>
#include <string>
#include <type_traits>
#include <vector>

struct M {
    int v;
    M(int x) : v(x) {}
    M(const M &o) : v(o.v) { std::printf("copy M\n"); }
    M(M &&o) noexcept : v(o.v) { std::printf("move M\n"); }
};
struct T {
    int v;
    T(int x) : v(x) {}
    T(const T &o) : v(o.v) { std::printf("copy T\n"); }
    T(T &&o) : v(o.v) { std::printf("move T\n"); }
};
struct P { std::string s; int k; };   // implicit members over a string's
struct Q { T t; };                    // an implicit move over T's, which may throw
struct D { D() {} };
struct E { E() noexcept {} };
struct A { A &operator=(const A &) { return *this; } };

int main() {
    std::vector<M> vm;
    vm.reserve(1);
    vm.emplace_back(1);
    vm.emplace_back(2);
    std::vector<T> vt;
    vt.reserve(1);
    vt.emplace_back(1);
    vt.emplace_back(2);
    std::printf("%d %d %d %d\n", (int) std::is_nothrow_move_constructible_v<M>, (int) std::is_nothrow_move_constructible_v<T>,
                (int) std::is_nothrow_move_constructible_v<P>, (int) std::is_nothrow_move_constructible_v<Q>);
    std::printf("%d %d %d %d\n", (int) std::is_nothrow_copy_constructible_v<M>, (int) std::is_nothrow_copy_constructible_v<std::string>,
                (int) std::is_nothrow_default_constructible_v<D>, (int) std::is_nothrow_default_constructible_v<E>);
    std::printf("%d %d %d %d\n", (int) std::is_nothrow_copy_assignable_v<A>, (int) std::is_nothrow_move_assignable_v<std::string>,
                (int) std::is_nothrow_constructible_v<int, double>, (int) std::is_nothrow_constructible_v<std::string, const char *>);
    return 0;
}
