// An integer type has one spelling: `signed int' is `int', `long int' is `long', `unsigned int' is
// `unsigned' -- in a specialization's pattern, a concept over it, and the instance a template makes.
#include <cstdio>
template <class T> struct is_si { static constexpr bool value = false; };
template <> struct is_si<signed char> { static constexpr bool value = true; };
template <> struct is_si<signed short> { static constexpr bool value = true; };
template <> struct is_si<signed int> { static constexpr bool value = true; };
template <> struct is_si<signed long> { static constexpr bool value = true; };
template <> struct is_si<long long int> { static constexpr bool value = true; };
template <class T> concept si = is_si<T>::value;
template <class, si T> int f() { return 1; }
template <class, class T> int f() { return 0; }
template <class T> int bump() { static int n = 0; return ++n; }
int main() {
  std::printf("%d %d %d %d %d %d %d %d\n", is_si<int>::value, is_si<long>::value, is_si<short>::value,
              is_si<char>::value, is_si<signed char>::value, is_si<long long>::value, is_si<unsigned>::value,
              is_si<long int>::value);
  std::printf("%d %d %d\n", f<void, int>(), f<void, unsigned>(), f<void, long>());
  bump<long>(); bump<long int>();
  std::printf("%d %d\n", bump<signed long>(), bump<unsigned int>() + bump<unsigned>());
  return 0;
}
