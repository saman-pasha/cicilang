/* C23's library over glibc (0.206): strdup and strndup, memccpy (its result borrows the destination), the searches,
   timegm and gmtime_r, strfromd and strfromf, mbrtoc8, printf's %b and its width modifiers %wN and %wfN, and strtol of
   a 0b literal. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <uchar.h>

int main(void) {
  char *d = strdup("hello");
  char *n = strndup("worldwide", 5);
  char buf[16] = {0};
  char *e = memccpy(buf, "abc,def", ',', sizeof buf);
  printf("dup %s %s %s %td\n", d, n, buf, e - buf);
  char buf2[8];
  char *mc = memcpy(buf2, "xyz", 4);
  char *hit = strstr(buf, "c,");
  const char *nohit = strchr(buf, 'z');
  printf("search %td %d %s\n", hit - buf, (int) (nohit == NULL), mc);
  free(d);
  free(n);
  struct tm tm = {.tm_year = 124, .tm_mon = 1, .tm_mday = 29, .tm_hour = 12};
  time_t t = timegm(&tm);
  struct tm g;
  gmtime_r(&t, &g);
  printf("time %lld %d %d\n", (long long) t, g.tm_yday, g.tm_wday);
  char fb[32];
  strfromd(fb, sizeof fb, "%.3f", 3.14159);
  char fb2[32];
  strfromf(fb2, sizeof fb2, "%g", 0.5f);
  printf("strfrom %s %s\n", fb, fb2);
  mbstate_t st = {0};
  char8_t c8 = 0;
  size_t r = mbrtoc8(&c8, "A", 1, &st);
  printf("mbrtoc8 %zu %d\n", r, (int) c8);
  printf("binary %b %#b %08b\n", 10u, 5u, 3u);
  int32_t w = 42;
  printf("width %w32d %wf16d\n", w, (int_fast16_t) 7);
  long v = strtol("0b1101", NULL, 0);
  printf("strtol %ld\n", v);
  return 0;
}
