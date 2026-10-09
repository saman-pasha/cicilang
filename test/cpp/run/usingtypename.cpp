// `using typename Base<T>::type;' in a class (0.117, reader 114): a TYPE brought from a base, the class-scope typedef `type' -- libc++ 18's <charconv>
// `__traits' writes it for its base's `using type = uint32_t;' and its members take `type &'. A static and a const member function use the name
#include <cstdio>
template <class T> struct Base { using type = unsigned; static type twice(type x) { return x * 2; } };
template <class T> struct Derived : Base<T> {
  using typename Base<T>::type;
  static type add(type a, type& b) { b = a + 1; return a + b; }
  type run(type v) const { type w = 0; return add(v, w) + w; }
};
int main() {
  Derived<int> d;
  unsigned w = 0;
  std::printf("%u %u %u\n", d.run(5), Derived<int>::add(7, w), w);
  return 0;
}
