// a VALUE template parameter hides a typedef or a template of the same name for its item: an earlier class has the
// typedef `_Size' and the algorithm template `count' exists, the parameters below are values
#include <cstdio>
#include <cstddef>
struct Other { typedef int _Size; };
template <class T> int count(T x) { return (int)x; }
template <size_t _Size> class bs {
  unsigned w;
public:
  bs() : w(0) {}
  bs &set(size_t p, bool v = true);
  bs &flip(size_t p);
  size_t count() const;
  bool test(size_t p) const;
  static constexpr size_t size() { return _Size; }
};
template <size_t _Size> inline bs<_Size> &bs<_Size>::set(size_t p, bool v) { if (v) w |= 1u << p; else w &= ~(1u << p); return *this; }
template <size_t _Size> inline bs<_Size> &bs<_Size>::flip(size_t p) { w ^= 1u << p; return *this; }
template <size_t _Size> inline size_t bs<_Size>::count() const { return __builtin_popcount(w); }
template <size_t _Size> inline bool bs<_Size>::test(size_t p) const { return (w >> p) & 1u; }
template <size_t count, size_t limit, bool small = (count < limit)> struct Pick { static int value() { return small ? 1 : 2; } };
int main() {
  bs<16> b;
  b.set(3);
  b.flip(0);
  b.set(5).set(7);
  std::printf("%zu %d %d %zu\n", b.count(), (int)b.test(3), (int)b.test(4), bs<16>::size());
  std::printf("%d %d %d\n", Pick<2, 5>::value(), Pick<6, 5>::value(), count(7));
  return 0;
}
