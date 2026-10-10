// `this' handed out of a constructor while an own field is still unset (0.133): `look' takes the object as complete
// and writes through the garbage in `buf'. Refused by the safe part: owner used before it was given anything.
#include <cstdio>
#include <cstdlib>
struct Q {
  own char *buf;
  Q();
  ~Q() { free(buf); }
};
void look(Q *q) { if (q->buf) q->buf[0] = 'x'; }
Q::Q() {
  look(this);
  buf = (char *) malloc(4);
}
int main() { Q q; std::printf("ok\n"); return 0; }
