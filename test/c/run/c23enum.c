/* C23's enumerations with a FIXED underlying type (6.7.2.2; 0.194): the enum is its base's size, and each enumerator is of
   the enum's type, so `sizeof' of one is the base's too (it was an int's 4) */
#include <stdio.h>
enum Big : unsigned long long { X = 1, Y = 0xFFFFFFFFFFULL };
enum Small : unsigned char { A1 = 1, A2 = 200 };
int main(void) {
  printf("%d %d %d %d %d\n", (int) sizeof(enum Big), (int) sizeof(Y), (int) sizeof(X), (int) sizeof(enum Small), (int) sizeof(A2));
  printf("%llu %d\n", (unsigned long long) Y, (int) A2);
  enum Small s = A2; printf("%d\n", s + 1);
  return 0;
}
