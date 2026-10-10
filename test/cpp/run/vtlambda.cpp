// A variable template whose value is a lambda CALLED IN PLACE, choosing by `if constexpr' over requires-expressions (libc++
// 21's format_kind), folded where a constant is wanted; and a partial specialization whose pattern names a SCOPED
// ENUMERATOR the reader takes for a type, `kind::map' with std::map declared.
#include <map>
#include <string>
#include <vector>
#include <cstdio>
enum class kind { none, seq, map };
template <class T> constexpr kind kind_of = [] {
  if constexpr (requires { typename T::key_type; }) return kind::map;
  else if constexpr (requires(T t) { t.begin(); }) return kind::seq;
  else return kind::none;
}();
template <kind K, class T> struct Show { static const char *name() { return "none"; } };
template <class T> struct Show<kind::seq, T> { static const char *name() { return "seq"; } };
template <class T> struct Show<kind::map, T> { static const char *name() { return "map"; } };
template <class T> const char *show() { return Show<kind_of<T>, T>::name(); }
int main() {
  std::printf("%d %d %d\n", (int) kind_of<int>, (int) kind_of<std::vector<int>>, (int) kind_of<std::map<std::string, int>>);
  std::printf("%s %s %s\n", show<int>(), show<std::vector<int>>(), show<std::map<int, int>>());
  return 0;
}
