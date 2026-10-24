#include <cstdio>
#include <cstdlib>
#include <new>
#include <string>
#include <vector>
// the program replaces the global allocation and deallocation functions ([new.delete.single], [new.delete.array],
// [replacement.functions]): every new-expression and the library's allocations call them
static int news, dels, anews, adels;
void *operator new(std::size_t n) { ++news; void *p = std::malloc(n ? n : 1); if (!p) throw std::bad_alloc(); return p; }
void operator delete(void *p) noexcept { if (p) ++dels; std::free(p); }
void operator delete(void *p, std::size_t) noexcept { if (p) ++dels; std::free(p); }
void *operator new[](std::size_t n) { ++anews; void *p = std::malloc(n ? n : 1); if (!p) throw std::bad_alloc(); return p; }
void operator delete[](void *p) noexcept { if (p) ++adels; std::free(p); }
void operator delete[](void *p, std::size_t) noexcept { if (p) ++adels; std::free(p); }
struct T { int v; T() : v(3) {} ~T() {} };
int main() {
  int *a = new int(5);
  T *t = new T;
  int *b = new int[4]{1, 2, 3, 4};
  T *ts = new T[3];
  std::printf("%d %d %d %d\n", *a, t->v, b[3], ts[2].v);
  delete a; delete t; delete[] b; delete[] ts;
  std::printf("%d %d %d %d\n", news, dels, anews, adels);
  int n0 = news;
  {
    std::vector<int> v;
    for (int i = 0; i < 10; ++i) v.push_back(i);
    std::string s(40, 'x');
    std::printf("%zu %zu\n", v.size(), s.size());
  }
  std::printf("%d %d\n", news > n0, news - n0 == dels - 2);
  void *raw = ::operator new(16);
  ::operator delete(raw);
  std::printf("%d %d\n", news - n0 > 0, dels);
  return 0;
}
