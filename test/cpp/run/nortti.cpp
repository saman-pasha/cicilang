// -fno-rtti (0.191): libc++'s no-RTTI configuration, as clang++ -fno-rtti builds it -- std::any and std::function
// without type(), target_type() and target<T>(); dynamic_cast to a base and to void *; an exception thrown and caught
#include <any>
#include <cstdio>
#include <functional>
#include <memory>
struct B { virtual ~B() {} int b = 1; };
struct D : B { int d = 2; };
struct E { int v; };
int twice(int x) { return 2 * x; }
int main() {
#ifdef __cpp_rtti
  std::printf("rtti\n");
#else
  std::printf("no rtti\n");
#endif
  std::any a = 5;
  std::printf("any_cast: %d %d\n", std::any_cast<int>(a), std::any_cast<long>(&a) == nullptr);
  std::function<int(int)> f = twice;
  std::printf("function: %d\n", f(21));
  std::shared_ptr<B> sb = std::make_shared<D>();
  std::printf("static_pointer_cast: %d\n", std::static_pointer_cast<D>(sb)->d);
  D d; B *pb = &d;
  std::printf("to a base and to void: %d %d\n", dynamic_cast<B *>(&d) == pb, dynamic_cast<void *>(pb) == (void *) &d);
  try { throw E{4}; } catch (const E &e) { std::printf("caught: %d\n", e.v); }
  return 0;
}
