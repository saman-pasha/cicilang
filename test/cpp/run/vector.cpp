// vector types in C++ the way libc++ 21's simd_utils.h writes them: an alias template over ext_vector_type, deduction of
// its element and lane count, a braced vector from a pack, a mask's lanes through __builtin_bit_cast, overloads by vector
#include <cstdio>
#include <cstddef>
#include <cstdint>
#include <utility>
template <class _Tp, std::size_t _Np>
using simd __attribute__((__ext_vector_type__(_Np))) = _Tp;
template <class _VecT> constexpr std::size_t lanes_v = 0;
template <class _Tp, std::size_t _Np> constexpr std::size_t lanes_v<simd<_Tp, _Np>> = _Np;
template <class _Tp, std::size_t _Np> _Tp elem_of(simd<_Tp, _Np>) { return _Tp{}; }
template <class _VecT, class _Iter> _VecT load(_Iter it) {
  return [&]<std::size_t... _Is>(std::index_sequence<_Is...>) { return _VecT{it[_Is]...}; }(std::make_index_sequence<lanes_v<_VecT>>{});
}
template <class _Tp, std::size_t _Np> bool all_of(simd<_Tp, _Np> v) { return __builtin_reduce_and(__builtin_convertvector(v, simd<bool, _Np>)); }
template <class _Tp, std::size_t _Np> std::size_t first_set(simd<_Tp, _Np> v) {
  using mask = simd<bool, _Np>;
  auto impl = [&]<class _M>(_M) { return __builtin_ctzll(__builtin_bit_cast(_M, __builtin_convertvector(v, mask)) | (1ull << _Np)); };
  if constexpr (sizeof(mask) == 1) return impl(std::uint8_t{});
  else return impl(std::uint16_t{});
}
typedef int v4si __attribute__((vector_size(16)));
int sum(v4si v) { return v[0] + v[1] + v[2] + v[3]; }
int sum(simd<short, 8> v) { return __builtin_reduce_add(v) * 1000; }
struct Pt { simd<float, 4> p; int id; };
int main() {
  int a[8] = {1, 2, 3, 4, 5, 6, 7, 8}, b[8] = {1, 2, 3, 9, 5, 6, 7, 8};
  using vec = simd<int, 4>;
  vec l = load<vec>(a), r = load<vec>(b);
  auto eq = l == r;
  std::printf("lanes %zu eq %d %d %d %d all %d first %zu\n", lanes_v<vec>, eq[0], eq[1], eq[2], eq[3], all_of(eq), first_set(~eq));
  vec l2 = load<vec>(a + 4), r2 = load<vec>(b + 4);
  std::printf("all %d first %zu sum %d\n", all_of(l2 == r2), first_set(~(l2 == r2)), sum(v4si{1, 2, 3, 4}));
  simd<short, 8> s = {1, 2, 3, 4, 5, 6, 7, 8};
  std::printf("short %d elem %zu\n", sum(s), sizeof(elem_of(s)));
  simd<unsigned char, 16> c{};
  c[3] = 7; c[15] = 1;
  std::printf("first16 %zu all16 %d\n", first_set(c), all_of(c));
  Pt p{{1.5f, 2.5f, 3.5f, 4.5f}, 3};
  p.p *= 2;
  std::printf("pt %g %g %g %g %d %zu\n", p.p[0], p.p[1], p.p[2], p.p[3], p.id, sizeof(Pt));
  return 0;
}
