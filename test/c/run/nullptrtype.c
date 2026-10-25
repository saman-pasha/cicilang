/* C23's nullptr_t (6.4.4.6, 7.21.2; 0.206): _Generic tells it from void *, a nullptr_t value converts to a null
   pointer and to false, and its size and alignment are a pointer's. */
#include <stddef.h>
#include <stdio.h>

int main(void) {
  nullptr_t n = nullptr;
  int *p = n;
  void *v = nullptr;
  printf("%d %d %d\n", _Generic(nullptr, nullptr_t: 1, void *: 2, default: 3), _Generic(v, nullptr_t: 1, void *: 2, default: 3),
         _Generic(n, nullptr_t: 1, default: 3));
  printf("%d %d %d\n", (int) sizeof(nullptr_t), (int) (p == nullptr), (int) (n == nullptr));
  bool b = nullptr;
  printf("%d %d\n", (int) b, (int) _Alignof(nullptr_t));
  return 0;
}
