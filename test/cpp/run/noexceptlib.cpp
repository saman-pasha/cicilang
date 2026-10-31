// noexcept(e) over library calls answers their declarations (0.193): a member function of a library class, its own, a
// member template's or a base's, and a free function of a header -- the C library's declared __THROW, which is
// noexcept(true) in C++ -- by its name or a qualified one; a program's own function of a name a header declares
// noexcept is the program's
#include <cstdio>
#include <cstring>
#include <algorithm>
#include <memory>
#include <sstream>
#include <string>
#include <utility>
#include <vector>
#ifdef __GLIBC__
#define CLIB_NX 1   // glibc declares its functions __THROW, noexcept(true) in C++
#else
#define CLIB_NX 0   // macOS's C library declares none so: the answer is the declaration's (0.250)
#endif

struct Box { int v; };
void swap(Box &a, Box &b) { std::swap(a.v, b.v); }   // the program's own `swap', not noexcept

int main() {
    std::vector<int> v{1, 2, 3};
    std::string s = "abc";
    std::unique_ptr<int> u;
    std::istringstream in("1");
    Box a{1}, b{2};
    std::printf("%d %d %d %d\n", (int) noexcept(v.at(0)), (int) noexcept(v.size()), (int) noexcept(v.push_back(4)),
                (int) noexcept(v.emplace_back(5)));
    std::printf("%d %d %d\n", (int) noexcept(s.c_str()), (int) noexcept(s.substr(1)), (int) noexcept(s.empty()));
    std::printf("%d %d %d %d\n", (int) noexcept(std::stoi(s)), (int) (noexcept(std::strlen("x")) == CLIB_NX), (int) noexcept(std::max(1, 2)),
                (int) noexcept(std::move(s)));
    std::printf("%d %d %d\n", (int) noexcept(u.get()), (int) noexcept(u.reset()), (int) noexcept(in.good()));
    std::printf("%d %d\n", (int) noexcept(swap(a, b)), (int) (noexcept(strlen("ab")) == CLIB_NX));
    swap(a, b);
    std::printf("%d %d %zu\n", a.v, b.v, v.size());
    return 0;
}
