// Class template argument deduction by the copy deduction candidate ([over.match.class.deduct]/1.3): one initializer
// of an instance's type gives that instance's arguments, the name bare or namespace-qualified. libc++ 18 writes
// `__format::__parse_number_result __r = __format::__parse_arg_id(...)'.
#include <cstdio>
namespace ns {
template <class It> struct R { It last; unsigned v; };
template <class It> R(It, unsigned) -> R<It>;
template <class It> R<It> mk(It b, unsigned n) { return {b, n}; }
}
int main() {
  ns::R r = ns::mk(40L, 7u);
  ns::R r2{3.5, 3u};
  ns::R r3 = r2;
  std::printf("%ld %u %g %u %g %d\n", r.last, r.v, r2.last, r2.v, r3.last, (int) sizeof(r));
  return 0;
}
