/* abi_targets.c: THE CALLING CONVENTIONS AND THE LAYOUTS OF THREE MACHINES (0.244) -- x86-64 Linux, Linux's aarch64 and Apple's
   arm64 -- as clang has them: integers narrower than 32 bits, `_Bool', `char', `long double', aggregates by value and returned
   (small ones, HFAs, ones passed in memory), a variadic definition and variadic calls, the zero-width bit-fields and the
   alignments. No header: the driver gate builds it for each machine with cicilang and with clang to IR, and compares the
   functions' conventions (test/abisig.awk) and the table `sizes' line for line. */
typedef __SIZE_TYPE__ size_t;
typedef __WCHAR_TYPE__ wchar_t;
int printf(const char *, ...);
int vsum(int n, ...) { __builtin_va_list ap; int s = n; __builtin_va_start(ap, n); s += __builtin_va_arg(ap, int); __builtin_va_end(ap); return s; }
struct s1 { char c; };
struct s3 { char a, b, c; };
struct s8 { int a, b; };
struct s12 { int a, b, c; };
struct s16 { long a, b; };
struct s24 { long a, b, c; };
struct hfa2 { double x, y; };
struct hfa4f { float a, b, c, d; };
struct hfa3d { double a, b, c; };
struct mix { float f; int i; };
struct bits { unsigned a : 3; int b : 5; };
signed char sc_id(signed char c) { return c; }
unsigned char uc_id(unsigned char c) { return c; }
char c_id(char c) { return c; }
short s_id(short v) { return v; }
unsigned short us_id(unsigned short v) { return v; }
_Bool b_id(_Bool v) { return v; }
wchar_t wc_id(wchar_t v) { return v; }
long double ld_id(long double v) { return v; }
int char_is_signed(void) { return (char) -1 < 0; }
struct s1 r1(struct s1 v) { return v; }
struct s3 r3(struct s3 v) { return v; }
struct s8 r8(struct s8 v) { return v; }
struct s12 r12(struct s12 v) { return v; }
struct s16 r16(struct s16 v) { return v; }
struct s24 r24(struct s24 v) { return v; }
struct hfa2 rh2(struct hfa2 v) { return v; }
struct hfa4f rh4(struct hfa4f v) { return v; }
struct hfa3d rh3(struct hfa3d v) { return v; }
struct mix rmix(struct mix v) { return v; }
struct bits rbits(struct bits v) { return v; }
int many(int a, int b, int c, int d, int e, int f, int g, int h, char i, short j, int k) { return a + b + c + d + e + f + g + h + i + j + k; }
double fmany(double a, double b, double c, double d, double e, double f, double g, double h, float i, double j) { return a + b + c + d + e + f + g + h + i + j; }
void calls(void) {
  struct s1 a1 = {1}; struct s3 a3 = {1, 2, 3}; struct s8 a8 = {1, 2}; struct s12 a12 = {1, 2, 3}; struct s16 a16 = {1, 2};
  struct s24 a24 = {1, 2, 3}; struct hfa2 h2 = {1, 2}; struct hfa4f h4 = {1, 2, 3, 4}; struct hfa3d h3 = {1, 2, 3}; struct mix m = {1, 2};
  char c = 'x'; short s = 7; signed char sc = -3; unsigned char uc = 200; _Bool b = 1; long double ld = 1.5L; float f = 2.5f;
  printf("%d %d %d %d %d %Lf %f\\n", c, s, sc, uc, b, ld, f);
  printf("%p %zu\\n", (void *) &a1, sizeof a24);
  vsum(10, a1, a3, a8, a12, a16, a24, h2, h4, h3, m);
  many(1, 2, 3, 4, 5, 6, 7, 8, c, s, 9);
  fmany(1, 2, 3, 4, 5, 6, 7, 8, f, 9);
  r1(a1); r3(a3); r8(a8); r12(a12); r16(a16); r24(a24); rh2(h2); rh4(h4); rh3(h3); rmix(m);
  sc_id(sc); uc_id(uc); c_id(c); s_id(s); us_id(7); b_id(b); wc_id(L'w'); ld_id(ld);
}
typedef __CHAR16_TYPE__ c16; typedef __CHAR32_TYPE__ c32; typedef __WCHAR_TYPE__ wc2;
enum small : short { SA = 1 };
enum usmall : unsigned char { UA = 1 };
enum plain { PA = 1 };
_Bool f_b(_Bool v) { return v; }
char f_c(char v) { return v; }
signed char f_sc(signed char v) { return v; }
unsigned char f_uc(unsigned char v) { return v; }
short f_s(short v) { return v; }
unsigned short f_us(unsigned short v) { return v; }
c16 f_c16(c16 v) { return v; }
c32 f_c32(c32 v) { return v; }
wc2 f_wc(wc2 v) { return v; }
enum small f_es(enum small v) { return v; }
enum usmall f_eus(enum usmall v) { return v; }
enum plain f_ep(enum plain v) { return v; }
_BitInt(7) f_bi7(_BitInt(7) v) { return v; }
unsigned _BitInt(17) f_bu17(unsigned _BitInt(17) v) { return v; }
int f_i(int v) { return v; }
#define OFF(t, m) __builtin_offsetof(t, m)
struct zb { char a; int : 0; char b; };
struct zb2 { char a; long long : 0; char b; };
struct bf1 { char a; int b : 3; char c; };
struct bf2 { short a : 4; char b; int c : 20; };
struct bf3 { long long a : 33; char b; };
struct ld { char c; long double d; };
struct pk { char a; int b; } __attribute__((packed));
struct al { char a; } __attribute__((aligned(16)));
struct fl { int n; char tail[]; };
union un { char c[5]; short s; };
struct wc { char c; __WCHAR_TYPE__ w; };
struct i128 { char c; __int128 i; };
struct boolstr { _Bool a; char b; _Bool c; };
struct dbl { char c; double d; };
struct ll { char c; long long l; };
struct ptrs { char c; void *p; };
struct f16 { char c; _Float16 h; };
size_t sizes[] = {
  sizeof(struct zb), _Alignof(struct zb), OFF(struct zb, b),
  sizeof(struct zb2), _Alignof(struct zb2), OFF(struct zb2, b),
  sizeof(struct bf1), _Alignof(struct bf1), OFF(struct bf1, c),
  sizeof(struct bf2), _Alignof(struct bf2), OFF(struct bf2, b),
  sizeof(struct bf3), _Alignof(struct bf3), OFF(struct bf3, b),
  sizeof(struct ld), _Alignof(struct ld), OFF(struct ld, d), sizeof(long double), _Alignof(long double),
  sizeof(struct pk), _Alignof(struct pk), OFF(struct pk, b),
  sizeof(struct al), _Alignof(struct al),
  sizeof(struct fl), _Alignof(struct fl), OFF(struct fl, tail),
  sizeof(union un), _Alignof(union un),
  sizeof(struct wc), _Alignof(struct wc), sizeof(__WCHAR_TYPE__),
  sizeof(struct i128), _Alignof(struct i128), OFF(struct i128, i),
  sizeof(struct boolstr), _Alignof(struct boolstr),
  sizeof(struct dbl), _Alignof(struct dbl), sizeof(struct ll), _Alignof(struct ll), sizeof(struct ptrs),
  sizeof(struct f16), _Alignof(struct f16), OFF(struct f16, h),
  sizeof(long), sizeof(void *), sizeof(_Bool), _Alignof(double), _Alignof(long long),
  (char) -1 < 0, (__WCHAR_TYPE__) -1 < 0, sizeof(size_t), sizeof(__PTRDIFF_TYPE__), sizeof(__INTMAX_TYPE__),
};
