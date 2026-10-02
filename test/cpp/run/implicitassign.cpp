// A class that writes operator= for another type only still has its implicit copy and move assignment, the exact
// match for a value of the class (0.112): libc++'s back_insert_iterator writes operator=(const value_type &), and
// `__out_it_ = std::move(__it)' (basic_format_context::advance_to) must copy the iterator, not push a byte
#include <cstdio>
#include <string>
#include <utility>
struct Sink { char buf[16]; int n = 0; void push_back(char c) { buf[n++] = c; } };
Sink sinks[2];
struct BackIns {
  int which;
  explicit BackIns(int w) : which(w) {}
  BackIns &operator=(const char &c) { sinks[which].push_back(c); return *this; }
  BackIns &operator=(char &&c) { sinks[which].push_back(c); return *this; }
};
struct Named {
  std::string name;
  int k = 0;
  Named &operator=(int v) { k = v; return *this; }
};
int main() {
  BackIns i(0), j(1);
  i = 'x';
  i = j;
  i = 'y';
  j = std::move(i);
  j = 'z';
  std::printf("%d %d %c %c %c\n", sinks[0].n, sinks[1].n, sinks[0].buf[0], sinks[1].buf[0], sinks[1].buf[1]);
  Named p, q;
  p.name = "first";
  q.name = "second";
  p = 7;
  q = p;
  std::printf("%s %d %s %d\n", q.name.c_str(), q.k, p.name.c_str(), p.k);
  return 0;
}
