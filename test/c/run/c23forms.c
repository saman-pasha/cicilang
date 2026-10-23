/* C23's smaller core forms: an unnamed parameter in a definition, a variadic function with no named parameter and
   va_start of one argument, a compound literal's storage class, constexpr compound literals, typeof_unqual, the
   keywords alignof, thread_local, static_assert, bool; nullptr_t; a label before a declaration */
#include <stdio.h>
#include <stdarg.h>
#include <stddef.h>
int unnamed(int, int b) { return b * 2; }
int sum(...) { va_list ap; va_start(ap); int a = va_arg(ap, int), b = va_arg(ap, int); va_end(ap); return a + b; }
int *keep(void) { return &(static int){ 7 }; }
int main(void) {
    constexpr int k = 3;
    const int ci = 5; typeof_unqual(ci) m = 6; m += 1;
    static_assert(alignof(double) >= 4);
    thread_local static int tl = 2;
    bool t = true; nullptr_t np = nullptr;
    printf("%d %d %d %d %d %d %d %d\n", unnamed(1, 4), sum(2, 3), *keep(), k, m, tl, (int) t, np == nullptr);
    goto out;
out:
    int after = 8;
    printf("%d\n", after);
    return 0;
}
