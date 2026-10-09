// sfinaetypedef: SFINAE on a typedef that names a scalar, and on a defaulted parameter that the call leaves out. A typedef naming a scalar has no
// member types: `typename U::iterator_category' with U = size_t kept the name `size_t' in its path, which flattened as a namespace and found
// some other class's typedef, so libc++'s `__has_iterator_typedefs<size_t>' held. And the TYPE of a defaulted parameter the call does not supply
// still substitutes ([temp.deduct]/7): libc++ 18's `list::insert' ends in `__enable_if_t<__has_input_iterator_category<_InpIter>::value> * = 0',
// and `l.assign(3, 4)' walked 400,000 flattened names (28 minutes, never finished) before the ranking dropped the template.
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <iterator>
#include <type_traits>

template <class T> struct has_ic {
  template <class U> static char test(...);
  template <class U> static long test(typename U::iterator_category * = nullptr);
  static const bool value = sizeof(test<T>(nullptr)) == sizeof(long);
};
struct I {
  typedef int iterator_category;
};
typedef unsigned long ulong_t;

template <class T> struct is_int_like { static const bool value = false; };
template <> struct is_int_like<int> { static const bool value = true; };
template <class T> const char *pick(T, typename std::enable_if<is_int_like<T>::value>::type * = nullptr) { return "int-like"; }
template <class T> const char *pick(T, typename std::enable_if<!is_int_like<T>::value>::type * = nullptr, int = 0) { return "other"; }

// an enumeration's name still finds its enumerators when a template parameter is bound to a typedef of it ([dcl.enum]/11)
enum Color { Red, Green };
typedef Color ColorT;
template <class E> int green() { return (int)E::Green; }

int main() {
  std::printf("%d %d\n", green<Color>(), green<ColorT>());
  std::printf("%d %d %d %d %d %d\n", (int)has_ic<size_t>::value, (int)has_ic<int>::value, (int)has_ic<I>::value,
              (int)has_ic<unsigned long>::value, (int)has_ic<ulong_t>::value, (int)has_ic<std::uint32_t>::value);
  std::printf("%s %s\n", pick(1), pick(2.5));
  return 0;
}
