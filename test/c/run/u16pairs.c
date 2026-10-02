/* A u"..." literal is UTF-16: a code point past U+FFFF is a surrogate pair, two units, in a pointer's literal, an array sized by it and sizeof (0.112) */
#include <stdio.h>
#include <uchar.h>
int main(void) {
  const char16_t *p = u"a\U0001F600b";
  char16_t arr[] = u"\U0001F600z";
  printf("%d %d %d\n", (int) (sizeof(u"a\U0001F600b") / sizeof(char16_t)), (int) (sizeof(arr) / sizeof(arr[0])), (int) sizeof(U"a\U0001F600b"));
  printf("%x %x %x %x\n", (unsigned) p[0], (unsigned) p[1], (unsigned) p[2], (unsigned) p[3]);
  printf("%x %x %x\n", (unsigned) arr[0], (unsigned) arr[1], (unsigned) arr[2]);
  return 0;
}
