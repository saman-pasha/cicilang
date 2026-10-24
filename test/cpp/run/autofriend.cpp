#include <cstdio>
#include <vector>
// a member whose deduced result calls a hidden friend of its own class: `operator[]' as `*(*this + n)' over a friend
// `operator+', as libc++ 21's __ra_iterator (flat_set's iterator) writes it
template <class C, class It>
struct RA {
  It it;
  using difference_type = long;
  constexpr decltype(auto) operator*() const { return *it; }
  constexpr decltype(auto) operator[](difference_type n) const { return *(*this + n); }
  constexpr auto at2() const { return (*this + 2).it - it; }
  friend constexpr RA operator+(const RA &i, difference_type n) {
    auto t = i;
    t.it += n;
    return t;
  }
  friend constexpr bool operator==(const RA &x, const RA &y) { return x.it == y.it; }
};
struct Tag {};
int main() {
  std::vector<int> v = {3, 5, 7, 9};
  RA<Tag, std::vector<int>::const_iterator> r{v.cbegin()};
  RA<Tag, std::vector<int>::const_iterator> s = r + 2;
  std::printf("%d %d %d %d %d\n", *r, r[1], *s, (int) (s == r + 2), (int) r.at2());
  return 0;
}
