#include <cstddef>
#include <cstdio>
#include <cstring>
#include <type_traits>
// GCC's packed and aligned attributes in C++: a packed class with members and a constructor, a packed derived class, a
// member's alignment, an alignas class nested, a packed enum, and values that cross a call
struct __attribute__((packed)) Hdr {
  unsigned char kind;
  unsigned int len;
  unsigned short crc;
  Hdr(unsigned char k, unsigned int l) : kind(k), len(l), crc(0xbeef) {}
  unsigned int total() const { return len + kind; }
};
struct Base { char tag; };
struct __attribute__((packed)) Der : Base { int v; long w; };
struct alignas(32) Big { char c; };
struct Hold { char x; Big b; short y; };
struct Pm { char c; double d __attribute__((packed)); char e; };
enum class Small : unsigned char { a, b };
enum __attribute__((packed)) Tiny { t0, t1 };
static Hdr make(unsigned int l) { return Hdr(3, l); }
static unsigned int sum(Hdr h) { return h.total() + h.crc; }
int main() {
  Hdr h(7, 70000);
  std::printf("%zu %zu %zu %zu\n", sizeof(Hdr), alignof(Hdr), offsetof(Hdr, len), offsetof(Hdr, crc));
  std::printf("%u %u %x\n", h.total(), sum(make(5)), h.crc);
  Hdr arr[3] = {Hdr(1, 10), Hdr(2, 20), Hdr(3, 30)};
  unsigned int t = 0;
  for (const Hdr &x : arr) t += x.len;
  std::printf("%u %d\n", t, (int) ((char *) &arr[2] - (char *) &arr[0]));
  Der d; d.tag = 1; d.v = 2; d.w = 3;
  std::printf("%zu %zu %zu %d %d %ld\n", sizeof(Der), offsetof(Der, v), offsetof(Der, w), d.tag, d.v, d.w);
  Hold ho; ho.y = 9; short y2; std::memcpy(&y2, (char *) &ho + offsetof(Hold, y), sizeof y2);
  std::printf("%zu %zu %zu %d\n", sizeof(Hold), offsetof(Hold, b), offsetof(Hold, y), y2);
  Pm p; p.d = 2.5; double d2; std::memcpy(&d2, (char *) &p + offsetof(Pm, d), sizeof d2);
  std::printf("%zu %zu %zu %g\n", sizeof(Pm), offsetof(Pm, d), offsetof(Pm, e), d2);
  std::printf("%zu %zu %d\n", sizeof(Small), sizeof(Tiny), (int) std::is_same_v<std::underlying_type_t<Tiny>, unsigned char>);
  return 0;
}
