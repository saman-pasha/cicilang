// A BRACED LIST FOR AN ARRAY PARAMETER holds only without NARROWING (0.121; [over.ics.list]/6, [dcl.init.list]/7): `D (&&)[1]' given `{declval<S>()}'
// is a substitution failure when S to D narrows -- int to double for a value that is no constant, double to int, a wider integer to a
// narrower, a pointer to bool -- and that is how libc++ 18's std::variant keeps an alternative out of its converting constructor.
#include <type_traits>
#include <utility>
#include <cstdio>
struct Check {
  template <class D> static auto test(D (&&)[1]) -> std::true_type;
  template <class D, class S> static auto apply(int) -> decltype(test<D>({std::declval<S>()}));
  template <class D, class S> static auto apply(...) -> std::false_type;
};
template <class D, class S> constexpr bool ok = decltype(Check::apply<D, S>(0))::value;
int main() {
  std::printf("%d %d %d %d\n", (int) ok<int, int>, (int) ok<double, int>, (int) ok<int, double>, (int) ok<float, double>);
  std::printf("%d %d %d %d\n", (int) ok<long, int>, (int) ok<int, long>, (int) ok<bool, int>, (int) ok<bool, const char *>);
  std::printf("%d %d %d %d\n", (int) ok<unsigned, int>, (int) ok<int, unsigned>, (int) ok<char, int>, (int) ok<double, float>);
  std::printf("%d %d %d\n", (int) ok<long long, unsigned>, (int) ok<short, char>, (int) ok<int, bool>);
  return 0;
}
