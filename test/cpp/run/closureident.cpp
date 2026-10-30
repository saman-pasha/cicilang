// 0.236: every lambda-expression's type is a class of its own ([expr.prim.lambda.closure]/1), and every local class's
// ([class.local]): two of one text in one function, at file scope, in two blocks, or in two instances of one function
// template are two types -- they were one where the text, the context and the captured types were one
#include <cstdio>
#include <type_traits>
#include <typeinfo>
auto ga = [] { return 1; };
namespace q { auto gb = [] { return 1; }; }
template <class T> auto mk() { return [] { return sizeof(T); }; }
template <class T> const std::type_info &loc() { struct L { int v; }; return typeid(L); }
int f1() { struct S { int v = 1; }; return S{}.v; }
int f2() { struct S { int v = 2; }; return S{}.v; }
int main() {
  auto a = [] {};
  auto b = [] {};
  auto c = [](int x) { return x; }; auto d = [](int x) { return x; };
  std::printf("%d %d %d %d %d\n", (int)std::is_same_v<decltype(a), decltype(b)>,
              (int)std::is_same_v<decltype(c), decltype(d)>, (int)std::is_same_v<decltype(ga), decltype(q::gb)>,
              (int)(typeid(a) == typeid(b)), (int)(typeid(c) == typeid(d)));
  std::printf("%d %d %d\n", (int)std::is_same_v<decltype(mk<int>()), decltype(mk<long>())>,
              (int)(loc<int>() == loc<char>()), (int)(loc<int>() == loc<int>()));
  std::printf("%d %d %d\n", f1(), f2(), c(3) + d(4));
  return 0;
}
