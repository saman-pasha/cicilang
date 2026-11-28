/* bitint.h -- the functions of bitint_main.c and bitint_helper.c (1.6.57): _BitInt values of each width that x86-64's
   psABI passes otherwise -- one INTEGER eightbyte for 33 to 63 bits, two for 65 to 128, memory past them -- in registers,
   after five longs where one register is left, as results, results of another type converted, through a pointer to a
   function, and through `...' into va_arg, the registers' save area and the overflow area both */
typedef _BitInt(48) B48;
typedef unsigned _BitInt(63) U63;
typedef _BitInt(65) B65;
typedef _BitInt(100) B100;
typedef unsigned _BitInt(127) U127;
typedef _BitInt(128) B128;
B48 h48(B48 a, int k);
U63 h63(U63 a);
B65 h65(B65 a, B65 b);
B100 h100(long a, long b, long c, long d, long e, B100 v, long f);
U127 h127(int k, U127 v);
B128 h128(long a, long b, long c, long d, long e, B128 v);
B100 hcall(B100 (*f)(B100, int), B100 v);
B100 m100(B100 v, int k);
B65 m65(long a, long b, long c, long d, long e, B65 v);
long hva(int n, ...);
B48 r48(long k);
B65 r65(int k);
#if defined(__x86_64__)
typedef _BitInt(129) B129;
typedef unsigned _BitInt(200) U200;
typedef _BitInt(256) B256;
B129 h129(B129 a, long k);
U200 h200(int k, U200 a, U200 b);
B256 h256(B256 a, long b, long c, long d, long e, long f, B256 g);
U200 m200(U200 v, int k);
long hvb(int n, ...);
U200 r200(long k);
#endif
