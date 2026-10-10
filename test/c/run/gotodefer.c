// A goto runs the defers of the scopes it leaves (0.133): out of a block and out of a loop's body, and back past a
// defer registered after its label.
#include <stdio.h>
int count = 0;
int jump(int k) {
  {
    defer(k) { printf("leave block %d\n", k); }
    for (int i = 0; i < 3; i++) {
      defer(i) { printf("iter %d\n", i); }
      if (i == k) goto done;
    }
    printf("loop ended\n");
  }
done:
  printf("done %d\n", k);
  return k;
}
int back(void) {
  int n = 0;
again:
  n++;
  defer(n) { printf("back %d\n", n); }
  if (n < 3) goto again;
  return n;
}
int main(void) { int r = jump(1) + jump(7) + back(); printf("%d\n", r); return 0; }
