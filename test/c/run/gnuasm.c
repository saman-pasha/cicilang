/* GNU's inline assembly (0.215; C17 J.5.10), lowered as clang lowers it: a file-scope asm is the module's, and an asm
   statement a call of an inline asm -- basic asm, and extended asm's outputs by value and by address, its inputs by
   value, in memory and as immediates, its in-out operands, its named operands and modifiers, `%=', `%%' and `$', its
   clobbers, a register variable's register; on x86-64 and on aarch64. Both forms were syntax errors */
#include <stdio.h>

#if defined(__APPLE__)
#define LBL "L"
__asm__(".data\n\t.p2align 2\n\t.globl _ccl_asm_val\n_ccl_asm_val:\n\t.long 42\n\t.text");
#else
#define LBL ".L"
__asm__(".pushsection .data\n\t.p2align 2\n\t.globl ccl_asm_val\nccl_asm_val:\n\t.long 42\n\t.popsection");
#endif
extern int ccl_asm_val;

#if defined(__x86_64__)
static int add(int a, int b) { int r; __asm__("addl %2, %0" : "=r"(r) : "0"(a), "r"(b)); return r; }
static int inc(int x) { asm volatile("incl %0" : "+r"(x)); return x; }
static int load(int *p) { int v; asm("movl %1, %0" : "=r"(v) : "m"(*p)); return v; }
static int seven(void) { int v; asm("movl %1, %0" : "=r"(v) : "i"(7)); return v; }
static int named(int a) { int r; asm("leal 1(%[in]), %[out]" : [out] "=r"(r) : [in] "r"(a)); return r; }
static int five(void) { int r; asm("movl $5, %0" : "=r"(r)); return r; }
static int three(void) { int r; asm("movl $3, %%eax\n\tmovl %%eax, %0" : "=r"(r) :: "eax", "cc"); return r; }
static void bump(int *p) { asm("addl $2, %0" : "+m"(*p)); }
static void swap(int *a, int *b) { int x = *a, y = *b; asm("xchgl %0, %1" : "+r"(x), "+r"(y)); *a = x; *b = y; }
static int either(int v) { asm("addl $1, %0" : "+rm"(v)); return v; }
static long wide(long a) { long r; asm("leaq 1(%1), %0" : "=r"(r) : "r"(a)); return r; }
static unsigned char low(unsigned a) { unsigned char r; asm("movb %b1, %0" : "=q"(r) : "q"(a)); return r; }
static int stored(void) { int v; asm("movl $6, %0" : "=m"(v)); return v; }
static int early(int a) { int r; asm("movl %1, %0\n\taddl $1, %0" : "=&r"(r) : "r"(a)); return r; }
static void pair(unsigned *lo, unsigned *hi) { unsigned a, d; asm("movl $1, %%eax\n\tmovl $2, %%edx" : "=a"(a), "=d"(d)); *lo = a; *hi = d; }
static int skip(void) { int r; asm("movl $9, %0\n\tjmp " LBL "ccl_skip%=\n\tmovl $0, %0\n" LBL "ccl_skip%=:" : "=r"(r)); return r; }
static void plain(void) { asm("# a basic asm's $ is its own"); }
static int regv(void) { register int r asm("eax") = 3; asm("addl $1, %%eax" : "+r"(r)); return r; }
#elif defined(__aarch64__)
static int add(int a, int b) { int r; __asm__("add %w0, %w0, %w2" : "=r"(r) : "0"(a), "r"(b)); return r; }
static int inc(int x) { asm volatile("add %w0, %w0, #1" : "+r"(x)); return x; }
static int load(int *p) { int v; asm("ldr %w0, %1" : "=r"(v) : "m"(*p)); return v; }
static int seven(void) { int v; asm("mov %w0, %1" : "=r"(v) : "i"(7)); return v; }
static int named(int a) { int r; asm("add %w[out], %w[in], #1" : [out] "=r"(r) : [in] "r"(a)); return r; }
static int five(void) { int r; asm("mov %w0, #5" : "=r"(r)); return r; }
static int three(void) { int r; asm("mov w9, #3\n\tmov %w0, w9" : "=r"(r) :: "w9", "cc"); return r; }
static void bump(int *p) { asm("ldr w9, %0\n\tadd w9, w9, #2\n\tstr w9, %0" : "+m"(*p) :: "w9"); }
static void swap(int *a, int *b) { int x = *a, y = *b; asm("mov w9, %w0\n\tmov %w0, %w1\n\tmov %w1, w9" : "+r"(x), "+r"(y) :: "w9"); *a = x; *b = y; }
static int either(int v) { asm("add %w0, %w0, #1" : "+r"(v)); return v; }
static long wide(long a) { long r; asm("add %0, %1, #1" : "=r"(r) : "r"(a)); return r; }
static unsigned char low(unsigned a) { unsigned char r; asm("and %w0, %w1, #255" : "=r"(r) : "r"(a)); return r; }
static int stored(void) { int v; asm("mov w9, #6\n\tstr w9, %0" : "=m"(v) :: "w9"); return v; }
static int early(int a) { int r; asm("mov %w0, %w1\n\tadd %w0, %w0, #1" : "=&r"(r) : "r"(a)); return r; }
static void pair(unsigned *lo, unsigned *hi) { unsigned a, d; asm("mov %w0, #1\n\tmov %w1, #2" : "=r"(a), "=r"(d)); *lo = a; *hi = d; }
static int skip(void) { int r; asm("mov %w0, #9\n\tb " LBL "ccl_skip%=\n\tmov %w0, #0\n" LBL "ccl_skip%=:" : "=r"(r)); return r; }
static void plain(void) { asm("// a basic asm's $ is its own"); }
static int regv(void) { register int r asm("w9") = 3; asm("add w9, w9, #1" : "+r"(r)); return r; }
#endif

int main(void) {
  int m = 9, a = 1, b = 2;
  unsigned lo, hi;
  asm("nop");
  __asm__ __volatile__("" ::: "memory");
  plain();
  bump(&m);
  swap(&a, &b);
  pair(&lo, &hi);
  printf("%d %d %d %d %d %d %d\n", ccl_asm_val, add(2, 3), inc(4), load(&m), seven(), named(1), five());
  printf("%d %d %d %d %ld %d %d %d\n", three(), a, b, either(1), wide(41), low(0x1234), stored(), early(1));
  printf("%u %u %d %d %d\n", lo, hi, skip(), skip(), regv());
  return 0;
}
