// std::nullptr_t is a type of its own ([basic.fundamental]/15; 0.206): its traits, decltype(nullptr) and its size, a
// template deducing it, overloads over void * and over it, its conversions to pointers, pointers to member and bool, a
// stream's inserter, typeid and its name, the smart pointers, hash<nullptr_t>, and a pointer to member a scalar.
#include <cstddef>
#include <cstdio>
#include <iostream>
#include <memory>
#include <sstream>
#include <type_traits>
#include <typeinfo>

template <class T> int kind(T) { return std::is_null_pointer_v<T> ? 1 : std::is_pointer_v<T> ? 2 : 3; }
int f(void *) { return 1; }
int f(std::nullptr_t) { return 2; }
int g(int *) { return 1; }
int g(long) { return 2; }
struct S { int m; int fn() { return 1; } };

int main() {
  std::printf("traits %d %d %d %d %d %d\n", (int) std::is_null_pointer_v<std::nullptr_t>, (int) std::is_null_pointer_v<void *>,
              (int) std::is_pointer_v<std::nullptr_t>, (int) std::is_same_v<std::nullptr_t, void *>,
              (int) std::is_fundamental_v<std::nullptr_t>, (int) std::is_scalar_v<std::nullptr_t>);
  std::printf("decltype %d %d\n", (int) std::is_same_v<decltype(nullptr), std::nullptr_t>, (int) sizeof(std::nullptr_t));
  void *vp = nullptr;
  std::printf("deduce %d %d %d\n", kind(nullptr), kind(vp), kind(0));
  std::printf("overload %d %d %d\n", f(nullptr), f(vp), g(nullptr));
  std::printf("convert %d %d %d %d\n", (int) std::is_convertible_v<std::nullptr_t, int *>, (int) std::is_convertible_v<void *, std::unique_ptr<int>>,
              (int) std::is_convertible_v<std::nullptr_t, std::unique_ptr<int>>, (int) std::is_convertible_v<std::nullptr_t, bool>);
  std::nullptr_t n = nullptr;
  int *ip = n;
  int S::*pm = n;
  int (S::*pf)() = n;
  bool b(n);
  std::printf("values %d %d %d %d %d\n", (int) (ip == nullptr), (int) (pm == nullptr), (int) (pf == nullptr), (int) b, (int) (n == nullptr));
  std::ostringstream os;
  os << nullptr;
  std::printf("stream %s\n", os.str().c_str());
  std::printf("typeid %d %s\n", (int) (typeid(nullptr) == typeid(std::nullptr_t)), typeid(std::nullptr_t).name());
  std::unique_ptr<int> u(nullptr);
  std::shared_ptr<int> sp = nullptr;
  std::printf("smart %d %d\n", (int) !u, (int) (sp == nullptr));
  int k = 0;
  std::printf("hash %d %d\n", (int) (std::hash<void *>{}(&k) != 662607004ull), (int) (std::hash<std::nullptr_t>{}(nullptr) == 662607004ull));
  std::printf("scalar %d %d %d\n", (int) std::is_scalar_v<int S::*>, (int) std::is_scalar_v<int (S::*)()>, (int) std::is_compound_v<std::nullptr_t>);
}
