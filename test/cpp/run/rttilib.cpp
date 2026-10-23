// libc++ built with RTTI, as clang++ builds it (0.191): std::any::type(), std::function::target_type() and target<T>(),
// std::get_deleter, std::dynamic_pointer_cast, typeid of a library class
#include <any>
#include <cstdio>
#include <functional>
#include <memory>
#include <string>
#include <typeinfo>

struct Base { virtual ~Base() {} virtual int f() const { return 1; } };
struct Derived : Base { int f() const override { return 2; } };
struct Del { int *hits; void operator()(own int *p) const { ++*hits; delete p; } };   // a deleter takes ownership: `own'
int twice(int x) { return 2 * x; }

int main() {
  std::any a = 5;
  std::printf("any int: %d %d\n", a.type() == typeid(int), a.type() == typeid(long));
  a = std::string("text");
  std::printf("any string: %d\n", a.type() == typeid(std::string));
  std::any e;
  std::printf("any empty: %d\n", e.type() == typeid(void));

  std::function<int(int)> fp = twice;
  std::printf("function target_type: %d\n", fp.target_type() == typeid(int (*)(int)));
  int (**pt)(int) = fp.target<int (*)(int)>();
  std::printf("function target: %d %d\n", pt != nullptr, pt ? (*pt)(21) : 0);
  std::printf("function wrong target: %d\n", fp.target<long>() == nullptr);
  std::function<int(int)> empty;
  std::printf("function empty target_type: %d\n", empty.target_type() == typeid(void));

  int hits = 0;
  {
    std::shared_ptr<int> sp(new int(7), Del{&hits});
    std::printf("get_deleter: %d %d\n", std::get_deleter<Del>(sp) != nullptr, std::get_deleter<int>(sp) == nullptr);
  }
  std::printf("deleter ran: %d\n", hits);

  std::shared_ptr<Base> b = std::make_shared<Derived>();
  std::shared_ptr<Derived> dp = std::dynamic_pointer_cast<Derived>(b);
  std::printf("dynamic_pointer_cast: %d %d\n", dp != nullptr, dp ? dp->f() : 0);
  std::shared_ptr<Base> b2 = std::make_shared<Base>();
  std::printf("dynamic_pointer_cast null: %d\n", std::dynamic_pointer_cast<Derived>(b2) == nullptr);
  std::printf("typeid string: %d\n", typeid(std::string) == typeid(std::basic_string<char>));
  return 0;
}
