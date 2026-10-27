// GNU's inline assembly in C++ (0.215; [dcl.asm]): an asm-declaration in a linkage block and in a namespace is the
// module's, and an asm statement in a member function, a function template and a lambda a call of an inline asm, its
// operands a member, a template's parameter and a capture. Both were syntax errors, and a file-scope one in C++ was
// taken for an attribute and dropped
#include <cstdio>

extern "C" {
#if defined(__APPLE__)
asm(".data\n\t.p2align 2\n\t.globl _ccl_cxx_val\n_ccl_cxx_val:\n\t.long 40\n\t.text");
#else
asm(".pushsection .data\n\t.p2align 2\n\t.globl ccl_cxx_val\nccl_cxx_val:\n\t.long 40\n\t.popsection");
#endif
extern int ccl_cxx_val;
}
namespace n {
#if defined(__APPLE__)
asm(".data\n\t.p2align 2\n\t.globl _ccl_ns_val\n_ccl_ns_val:\n\t.long 2\n\t.text");
#else
asm(".pushsection .data\n\t.p2align 2\n\t.globl ccl_ns_val\nccl_ns_val:\n\t.long 2\n\t.popsection");
#endif
}
extern "C" int ccl_ns_val;

#if defined(__x86_64__)
#define INC "incl %0"
#define ADD "addl %2, %0"
#elif defined(__aarch64__)
#define INC "add %w0, %w0, #1"
#define ADD "add %w0, %w0, %w2"
#endif

struct counter {
  int v = 5;
  void bump() { asm volatile(INC : "+r"(v) :: "cc"); }
  int plus(int k) const { int r; asm(ADD : "=r"(r) : "0"(v), "r"(k)); return r; }
};
template <class T> T inc(T x) { asm(INC : "+r"(x)); return x; }
int main() {
  counter c;
  c.bump();
  auto twice = [&c](int k) { int r = k; asm(INC : "+r"(r)); asm(INC : "+r"(r)); return c.plus(r); };
  asm("nop");
  asm volatile("" ::: "memory");
  std::printf("%d %d %d %d\n", ccl_cxx_val + ccl_ns_val, c.v, inc(41), twice(1));
  return 0;
}
