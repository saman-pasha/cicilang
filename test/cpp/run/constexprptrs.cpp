// constexpr pointers (1.6.24): the object is const, so the pointer is, `const char *const' -- the reader held the const
// on what it points to, `const const char' -- and reads of it, an array's elements, a static member's and a deduction of
// its type are as before; an assignment to one is refused in clang++'s words (the driver gate)
#include <cstdio>
constexpr const char *m = "x";
constexpr const char *names[] = {"a", "bc"};
int g = 5;
constexpr int *p = nullptr;
constexpr int (*fp)(int) = nullptr;
struct K { static constexpr const char *nm = "kk"; };
template <class T> const char *kind(T &) { return "lv"; }
int main() { const char *q = m; std::printf("%s %s %s %s %d %d\n", q, names[1], K::nm, kind(m), p == nullptr, fp == nullptr); return 0; }
