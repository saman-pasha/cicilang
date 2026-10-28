/* the type of a conditional of two object pointers (0.219; C17 6.5.15/6): differently qualified versions of one type give
   the type with both arms' qualifiers; incompatible types are a constraint violation that clang and gcc type as a plain
   `void *', with a warning -- it took the first arm's type */
#include <stdio.h>
int main(int argc, char **argv) {
  int i = 7; float f = 2.5f; int *p = &i; float *q = &f; const int *c = &i; (void)argv;
  printf("%d %d %d %d\n", _Generic(argc > 5 ? p : q, void *: 1, default: 0), _Generic(argc > 5 ? c : q, const void *: 1, void *: 2, default: 0),
         _Generic(argc > 5 ? p : c, const int *: 1, int *: 2, default: 0), _Generic(argc > 5 ? p : p, int *: 1, default: 0));
  void *r = argc > 5 ? p : q;
  printf("%d\n", r == (void *)q);
  return 0;
}
