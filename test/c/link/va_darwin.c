/* va_arg of aggregates on Apple's arm64 (0.160). No Apple machine is here, so the driver gate compiles this walk for
   arm64-apple-macos with cicilang and with clang, retargets both texts to this host, and runs each over one buffer laid
   out as Apple's ABI lays the variadic arguments out (va_darwin_main.c): 8-byte slots, a value aligned past 8 at its
   alignment, a composite past 16 bytes that is no HFA by a pointer. Only aggregates: a scalar is LLVM's own va_arg. */
#include <stdarg.h>
struct small { char c; short s; };
struct two { long a, b; };
struct big { long a, b, c; };
struct hfa3 { double x, y, z; };
struct hfa2f { float x, y; };
struct al16 { __int128 v; };
union u { long i; double d; };
void WALK(long *o, va_list ap) {
    struct small s = va_arg(ap, struct small);           o[0] = s.c; o[1] = s.s;
    struct two t = va_arg(ap, struct two);               o[2] = t.a; o[3] = t.b;
    struct big b = va_arg(ap, struct big);               o[4] = b.a; o[5] = b.b; o[6] = b.c;
    struct hfa3 h = va_arg(ap, struct hfa3);             o[7] = (long) h.x; o[8] = (long) h.y; o[9] = (long) h.z;
    struct hfa2f f = va_arg(ap, struct hfa2f);           o[10] = (long) f.x; o[11] = (long) f.y;
    struct al16 a = va_arg(ap, struct al16);             o[12] = (long) a.v; o[13] = (long) (a.v >> 64);
    union u v = va_arg(ap, union u);                     o[14] = v.i;
    _Complex double z = va_arg(ap, _Complex double);     o[15] = (long) __real__ z; o[16] = (long) __imag__ z;
    struct two t2 = va_arg(ap, struct two);              o[17] = t2.a; o[18] = t2.b;
}
