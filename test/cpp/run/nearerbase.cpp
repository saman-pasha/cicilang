// Of two candidates that tie on their conversions, the one that takes a derived class as a nearer base wins
// ([over.ics.rank]/4.4.4; 0.206): the plain road's tie-break and the template road's demerits.
#include <cstdio>
#include <iterator>
#include <vector>
int f(std::input_iterator_tag) { return 1; }
int f(std::forward_iterator_tag) { return 2; }
struct A {};
struct B : A {};
struct C : B {};
int g(A) { return 1; }
int g(B) { return 2; }
struct M {
  int h(const A &) const { return 1; }
  int h(const B &) const { return 2; }
};
template <class It> int pick(It, std::input_iterator_tag) { return 1; }
template <class It> int pick(It, std::forward_iterator_tag) { return 2; }
template <class It> int pick(It, std::bidirectional_iterator_tag) { return 3; }
template <class It> int pick(It i) { return pick(i, typename std::iterator_traits<It>::iterator_category()); }
struct FwdIt {
  using iterator_category = std::forward_iterator_tag;
  using value_type = int;
  using difference_type = long;
  using pointer = int *;
  using reference = int &;
};
int main() {
  std::printf("tags %d %d %d\n", f(std::random_access_iterator_tag{}), f(std::input_iterator_tag{}),
              f(std::bidirectional_iterator_tag{}));
  std::printf("bases %d %d\n", g(C{}), g(A{}));
  M m;
  std::printf("method %d %d\n", m.h(C{}), m.h(A{}));
  std::vector<int> v{1};
  std::printf("templates %d %d %d\n", pick(v.begin()), pick(FwdIt{}), pick(v.data()));
}
