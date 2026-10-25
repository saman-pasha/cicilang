#include <atomic>
#include <cstdio>
struct alignas(4) S { short a, b; };
struct P { short a, b; };
int main() {
  S s{1, 2};
  std::atomic_ref<S> r(s);
  S t = r.load();
  r.store(S{3, 4});
  alignas(4) P p{5, 6};
  std::atomic_ref<P> q(p);
  P u = q.load();
  q.store(P{7, 8});
  P w = q.exchange(P{9, 10});
  std::printf("%d %d %d %d %d %d %d %d\n", t.a, t.b, s.a, s.b, u.a + u.b, w.a, p.a, (int) std::atomic_ref<P>::required_alignment);
  return 0;
}
