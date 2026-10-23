/* GCC'S LOCK-FREE BUILTINS (0.194): __atomic_always_lock_free(size, ptr) a constant -- the widths 1, 2, 4 and 8, where the
   pointer is null or its pointee aligned to the size -- and __atomic_is_lock_free(size, ptr) at run time */
#include <stdio.h>
_Static_assert(__atomic_always_lock_free(8, 0), "8 bytes are lock-free");
int main(void) {
  int x = 0; long l = 0;
  printf("%d %d %d %d\n", __atomic_always_lock_free(4, 0), __atomic_always_lock_free(8, &x), __atomic_always_lock_free(16, 0), __atomic_always_lock_free(8, &l));
  printf("%d %d\n", __atomic_is_lock_free(4, &x), __atomic_is_lock_free(8, &l));
  return 0;
}
