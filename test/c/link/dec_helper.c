/* the decimal floating types across the SysV ABI (0.129): built by gcc and by cicilang, called both ways (test/driver.sh) */
#include <stdarg.h>
struct q { _Decimal128 v; };
struct p { _Decimal64 a; _Decimal32 b; };
struct q twice(struct q x) { struct q r = { x.v * 2 }; return r; }
struct p swap(struct p x) { struct p r = { x.b, x.a }; return r; }
_Decimal64 sum(int n, ...) { va_list ap; va_start(ap, n); _Decimal64 s = 0; for (int i = 0; i < n; i++) s += va_arg(ap, _Decimal64); va_end(ap); return s; }
_Decimal32 mix(_Decimal32 a, _Decimal64 b, _Decimal128 c, int k) { return (_Decimal32)(a + b + c + k); }
_Decimal128 cube(_Decimal128 x) { return x * x * x; }
