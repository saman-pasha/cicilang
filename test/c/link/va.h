/* variadic calls by value of every AAPCS64 kind (0.131): va_mix(kinds, ...) is defined in va_func.c and called from
   va_main.c, each built by cicilang --target=aarch64-linux-gnu or by aarch64-linux-gnu-gcc, both ways */
typedef struct { double x, y; } vd2;      /* an HFA of doubles: two SIMD registers */
typedef struct { float a, b, c; } vf3;    /* an HFA of floats: three, its members gathered */
typedef struct { long a, b, c; } vl3;     /* past 16 bytes: by reference */
typedef struct { int a; char b; } vic;    /* eight bytes: one general register */
typedef struct { __int128 v; } vq;        /* aligned 16: an even pair of general registers */
double va_mix(const char *kinds, ...);
